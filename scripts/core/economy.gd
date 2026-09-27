class_name Economy
extends RefCounted
## Soft-currency rules: coin rewards, Silver/Gold reward blocks, Chapter
## chests, Chapter milestones and the booster shop. Every number comes from
## res://data/economy.json so the economy can be tuned without touching
## code. Coins are never bought with real money.
##
## Anti-farming is a rule of every reward here: something pays only the
## FIRST time it is earned, and that fact is saved immediately.

const CONFIG_PATH := "res://data/economy.json"

static var _config: Dictionary = {}


static func config() -> Dictionary:
	if _config.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		_config = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _config


static func price(item: String) -> int:
	return int(config()["prices"][item])


## Level-reward multiplier for a Chapter (1-based). Chapters past the table
## keep rising by "step" up to "max".
static func chapter_multiplier(chapter: int) -> float:
	var table: Array = config()["chapter_multiplier"]
	if chapter <= table.size():
		return float(table[maxi(chapter, 1) - 1])
	var extra := (chapter - table.size()) * float(config().get("chapter_multiplier_step", 0.1))
	return minf(float(table[-1]) + extra, float(config().get("chapter_multiplier_max", 3.0)))


## Coins for finishing a level. Only IMPROVEMENTS pay: a first clear, each
## star earned for the first time, the first PERFECT. Later Chapters pay
## more. Replaying without improving pays nothing, so easy levels can't be
## farmed. Returns {"coins": int, "lines": Array[String]}.
static func level_reward(level_number: int, first_clear: bool, prev_stars: int, stars: int,
		first_perfect: bool) -> Dictionary:
	var r: Dictionary = config()["rewards"]
	var mult := chapter_multiplier(Chapters.chapter_of(level_number))
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


# --- Reward blocks (Silver / Gold) ------------------------------------------

## Coins a rarity pays (0 for normal blocks and disabled rarities).
static func reward_block_coins(rarity: int) -> int:
	if rarity <= BlockData.Rarity.NORMAL:
		return 0
	var cfg: Dictionary = config().get("reward_blocks", {}).get(BlockData.RARITY_NAMES[rarity], {})
	if not bool(cfg.get("enabled", false)):
		return 0
	return int(cfg.get("coins", 0))


## Pays for a reward block that escaped by NORMAL play (never a Hammer).
## Each block pays once per save: the key is recorded and saved at once, so
## Undo, Restart, Replay, out-of-hearts and relaunching can never pay it
## again. Returns the coins awarded (0 if already collected).
static func collect_reward_block(progress: PlayerProgress, level_number: int, block: BlockData) -> int:
	var coins := reward_block_coins(block.rarity)
	if coins <= 0 or progress.has_reward_block(level_number, block.id):
		return 0
	progress.reward_blocks.append(PlayerProgress.reward_key(level_number, block.id))
	progress.add_coins(coins, Chapters.chapter_of(level_number))
	progress.save()
	return coins


# --- Chapter chests --------------------------------------------------------

static func chapter_stars(progress: PlayerProgress, chapter: int) -> int:
	var rg := Chapters.chapter_range(chapter)
	var t := 0
	for n in range(rg.x, rg.y + 1):
		t += progress.stars_for(n)
	return t


## For each tier: {"name", "stars", "coins", "items", "claimed", "claimable"}.
static func chest_tiers(progress: PlayerProgress, chapter: int) -> Array:
	var have := chapter_stars(progress, chapter)
	var out := []
	for i in config()["chest_tiers"].size():
		var tier: Dictionary = config()["chest_tiers"][i]
		var claimed := progress.claimed_chests.has(chest_id(chapter, i))
		out.append({"name": String(tier.get("name", "Tier %d" % (i + 1))), "stars": int(tier["stars"]),
			"coins": int(tier["coins"]), "items": tier.get("items", {}), "claimed": claimed,
			"claimable": not claimed and have >= int(tier["stars"])})
	return out


## "g3_t1" = Chapter 4, tier 2. Same ids as the v0.4 chests (which were
## already per 10 levels), so chests claimed before v0.5 stay claimed.
static func chest_id(chapter: int, tier: int) -> String:
	return "g%d_t%d" % [chapter - 1, tier]


## The best tier the Chapter's stars have reached (-1 = none yet).
static func chest_level(progress: PlayerProgress, chapter: int) -> int:
	var best := -1
	for i in chest_tiers(progress, chapter).size():
		if chapter_stars(progress, chapter) >= int(config()["chest_tiers"][i]["stars"]):
			best = i
	return best


## Claims one chest tier once. Returns the coins awarded (0 if not claimable
## or already claimed - rewards can never be duplicated). Booster items in
## the tier go to the inventory.
static func claim_chest(progress: PlayerProgress, chapter: int, tier: int) -> int:
	var tiers := chest_tiers(progress, chapter)
	if tier < 0 or tier >= tiers.size() or not tiers[tier]["claimable"]:
		return 0
	progress.claimed_chests.append(chest_id(chapter, tier))
	progress.add_coins(tiers[tier]["coins"], chapter)
	var items: Dictionary = tiers[tier]["items"]
	for item in items:
		progress.inventory[item] = int(progress.inventory.get(item, 0)) + int(items[item])
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


# --- Chapter milestone ------------------------------------------------------

static func is_chapter_cleared(progress: PlayerProgress, chapter: int, total_levels: int) -> bool:
	var rg := Chapters.chapter_range(chapter)
	if rg.x > total_levels:
		return false
	for n in range(rg.x, mini(rg.y, total_levels) + 1):
		if not progress.best_scores.has(n):
			return false
	return true


## Chapter milestone: every level of the Chapter cleared. Fires and pays
## ONCE per save. Returns the coins awarded (0 = not complete / already).
static func check_chapter_complete(progress: PlayerProgress, chapter: int, total_levels: int) -> int:
	if progress.completed_chapters.has(chapter) or not is_chapter_cleared(progress, chapter, total_levels):
		return 0
	progress.completed_chapters.append(chapter)
	var coins := int(config()["rewards"]["chapter_complete"])
	progress.add_coins(coins, chapter)
	progress.save()
	return coins
