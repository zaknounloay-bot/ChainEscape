class_name Economy
extends RefCounted
## Soft-currency rules: coin rewards, treasure chests and the booster shop.
## Every number comes from res://data/economy.json so the economy can be
## tuned without touching code. Coins are never bought with real money.

const CONFIG_PATH := "res://data/economy.json"

static var _config: Dictionary = {}


static func config() -> Dictionary:
	if _config.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		_config = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _config


static func price(item: String) -> int:
	return int(config()["prices"][item])


static func world_of(level_number: int) -> int:
	return clampi((level_number - 1) / 20 + 1, 1, 5)


## Coins for finishing a level. Only IMPROVEMENTS pay: a first clear, each
## star earned for the first time, the first PERFECT. Harder worlds pay
## more. Replaying without improving pays nothing, so easy levels can't be
## farmed. Returns {"coins": int, "lines": Array[String]}.
static func level_reward(level_number: int, first_clear: bool, prev_stars: int, stars: int,
		first_perfect: bool) -> Dictionary:
	var r: Dictionary = config()["rewards"]
	var mult: float = config()["world_multiplier"][world_of(level_number) - 1]
	var base := 0
	var lines: Array[String] = []
	if first_clear:
		base += int(r["first_clear"])
		lines.append("Clear")
	var new_stars := maxi(0, stars - prev_stars)
	if new_stars > 0:
		base += new_stars * int(r["per_new_star"])
		lines.append("+%d star%s" % [new_stars, "s" if new_stars > 1 else ""])
	if first_perfect:
		base += int(r["first_perfect"])
		lines.append("PERFECT")
	return {"coins": int(round(base * mult)), "lines": lines}


# --- Treasure chests -------------------------------------------------------

static func group_count(total_levels: int) -> int:
	return int(ceil(total_levels / float(config()["chest_group_size"])))


static func group_range(group: int) -> Vector2i:
	var size: int = config()["chest_group_size"]
	return Vector2i(group * size + 1, (group + 1) * size)


static func group_stars(progress: PlayerProgress, group: int) -> int:
	var rg := group_range(group)
	var t := 0
	for n in range(rg.x, rg.y + 1):
		t += progress.stars_for(n)
	return t


## For each tier: {"stars", "coins", "claimed", "claimable"}.
static func chest_tiers(progress: PlayerProgress, group: int) -> Array:
	var have := group_stars(progress, group)
	var out := []
	for i in config()["chest_tiers"].size():
		var tier: Dictionary = config()["chest_tiers"][i]
		var claimed := progress.claimed_chests.has(chest_id(group, i))
		out.append({"stars": int(tier["stars"]), "coins": int(tier["coins"]), "claimed": claimed,
			"claimable": not claimed and have >= int(tier["stars"])})
	return out


static func chest_id(group: int, tier: int) -> String:
	return "g%d_t%d" % [group, tier]


## Claims a chest once. Returns the coins awarded (0 if not claimable or
## already claimed - rewards can never be duplicated).
static func claim_chest(progress: PlayerProgress, group: int, tier: int) -> int:
	var tiers := chest_tiers(progress, group)
	if tier < 0 or tier >= tiers.size() or not tiers[tier]["claimable"]:
		return 0
	progress.claimed_chests.append(chest_id(group, tier))
	progress.coins += tiers[tier]["coins"]
	progress.save()
	return tiers[tier]["coins"]


# --- Shop ------------------------------------------------------------------

## Buys one booster. Returns false (and changes nothing) if too poor.
static func buy(progress: PlayerProgress, item: String) -> bool:
	var cost := price(item)
	if progress.coins < cost:
		return false
	progress.coins -= cost
	progress.inventory[item] = progress.inventory.get(item, 0) + 1
	progress.save()
	return true


## World milestone: all levels of a world cleared. Pays once.
static func check_world_complete(progress: PlayerProgress, world: int, total_levels: int) -> int:
	if progress.completed_worlds.has(world):
		return 0
	var first := (world - 1) * 20 + 1
	var last := mini(world * 20, total_levels)
	for n in range(first, last + 1):
		if not progress.best_scores.has(n):
			return 0
	progress.completed_worlds.append(world)
	var coins := int(config()["rewards"]["world_complete"])
	progress.coins += coins
	progress.save()
	return coins
