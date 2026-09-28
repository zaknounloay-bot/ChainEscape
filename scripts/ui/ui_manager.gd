class_name UIManager
extends CanvasLayer
## Gameplay HUD: level title, board progress, hearts, chain counter,
## Undo/Hint/Restart, settings and the level-complete / try-again card.
## Emits intent signals; never touches game state.

signal undo_pressed
signal restart_pressed
signal next_pressed
signal hint_pressed
signal replay_pressed
signal hammer_pressed
signal buy_requested(item: String)
signal chest_claim(chapter: int, tier: int)
signal chapter_continue  # CONTINUE on the Chapter Complete card
signal continue_pressed
signal title_level_select
signal shop_open_requested
signal level_chosen(number: int)
signal levels_opened  # GameManager fills the grid via open_level_select()
signal setting_toggled(key: String, on: bool)  # "music" | "sfx" | "haptics"
signal title_tapped  # used as a hidden debug gesture on devices
signal backup_requested  # Settings: BACKUP CODE
signal restore_requested  # Settings / recovery: RESTORE FROM CODE
signal recovery_new_game  # recovery: START NEW GAME (confirmed)

const TOP_HEIGHT := 290.0
const BOTTOM_HEIGHT := 190.0

var _root: Control
var _top: VBoxContainer
var _bottom: HBoxContainer
var _level_label: Label
var _name_label: Label
var _progress: BoardProgress
var _chain_label: Label
var _undo_button: PillButton
var _restart_button: PillButton
var _hint_button: PillButton
var _hearts: HeartsBar
var _hearts_holder: CenterContainer
var _settings_button: PillButton
var _settings_overlay: ColorRect
var _setting_buttons: Dictionary = {}  # key -> PillButton
var _settings: Dictionary = {"music": true, "sfx": true, "haptics": true}
## Score model (v0.5.2) - every number says what it is:
##   TOTAL SCORE = sum of the best score of every completed level. It never
##                 goes down. It is THE big number on the level card and the
##                 one shown in the HUD, title and Level Select.
##   LEVEL SCORE = this attempt on this level (a smaller, labelled line).
##   LEVEL BEST  = this level's personal best.
var _card_reward: Label  # "NEW BEST!" / "LEVEL BEST  1,234"
var _card_score: Label  # the big number: TOTAL SCORE
var _card_score_caption: Label  # "TOTAL SCORE"
var _card_gain: Label  # "+800" (how much this run added to the total)
var _card_total: Label  # "LEVEL SCORE  6,000"
var _card_count: Tween
## HUD chip (top-left, opposite the coin pill): "TOTAL SCORE / 229,653".
var _hud_total: VBoxContainer
var _hud_total_caption: Label
var _hud_total_value: Label
var _card_stars: StarsRow
var _card_buttons: HBoxContainer
var _replay_button: PillButton
var _card_style: StyleBoxFlat
var _levels_button: PillButton
var _level_select: LevelSelect
var _stamp: Label
var _hammer_button: PillButton
var _coin_pill: CoinPill
var _shop: ShopPanel
var _title: TitleScreen
var _banner: Label
var _card_coins: Label
var _chapter_card: ChapterCard
## Current Chapter theme (HUD colors follow it).
var theme: Dictionary = Chapters.theme_for_chapter(1)
var _overlay: ColorRect
var _card: PanelContainer
var _card_title: Label
var _card_stats: Label
var _next_button: PillButton
var _chain_tween: Tween
var _safe_top := 0.0
var _safe_bottom := 0.0


func _ready() -> void:
	_build()
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()


## Canvas-space rectangle where the board may be placed.
func get_board_area() -> Rect2:
	var vis := get_viewport().get_visible_rect()
	var top := _safe_top + TOP_HEIGHT
	var bottom := vis.size.y - _safe_bottom - BOTTOM_HEIGHT
	var side := 24.0
	return Rect2(Vector2(side, top), Vector2(vis.size.x - side * 2.0, maxf(bottom - top, 100.0)))


func set_level(number: int, total: int, level_name: String, mystery: bool = false) -> void:
	var master := Chapters.is_master(number)
	var grand := master and number > Chapters.master_level()
	_level_label.text = ("GRAND MASTER" if grand else "MASTER LEVEL") if master else "LEVEL %d" % number
	_level_label.add_theme_font_size_override("font_size", 50 if master else 64)
	# "DEADBOLT  ·  CHAPTER 5  ·  5/10": where you are inside the Chapter.
	var per := Chapters.levels_per_chapter()
	_name_label.text = level_name.to_upper() if total == 0 else "%s  ·  CHAPTER %d  ·  %d/%d" % [
		level_name.to_upper(), Chapters.chapter_of(number), (number - 1) % per + 1, per]
	if mystery:
		_name_label.text = "?  MYSTERY  ·  " + _name_label.text
	# Long lines (mystery + long names) step down a size to stay on one line.
	_name_label.add_theme_font_size_override("font_size", 24 if _name_label.text.length() <= 40 else 20)
	var mystery_col := Color("#C9A8FF") if theme["dark"] else Palette.PURPLE_BADGE
	_name_label.add_theme_color_override("font_color", mystery_col if mystery else theme["text_soft"])
	_level_label.add_theme_color_override("font_color", Palette.GOLD if master or Chapters.is_milestone(number) else theme["text"])
	hide_complete()
	_chain_label.modulate.a = 0.0


func set_progress(fraction: float, animate: bool = true) -> void:
	_progress.set_progress(fraction, animate)


## Hearts row; max_hearts 0 hides it (onboarding levels).
func set_hearts(max_hearts: int, current: int) -> void:
	_hearts_holder.modulate.a = 1.0 if max_hearts > 0 else 0.0
	if max_hearts > 0:
		_hearts.set_hearts(max_hearts, current)


func lose_heart() -> void:
	_hearts.lose_heart()


## Shows the hint token count on the Hint button ("∞"-style text in debug).
func set_hint_count(text: String) -> void:
	_hint_button.badge_text = text


func pulse_hint_button() -> void:
	_pulse(_hint_button)


func pulse_undo_button() -> void:
	_pulse(_undo_button)


func _pulse(b: Control) -> void:
	b.pivot_offset = b.size * 0.5
	var t := create_tween()
	for i in 2:
		t.tween_property(b, "scale", Vector2(1.1, 1.1), 0.12).set_trans(Tween.TRANS_SINE)
		t.tween_property(b, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE)


func apply_settings(music: bool, sfx: bool, haptics: bool) -> void:
	_settings = {"music": music, "sfx": sfx, "haptics": haptics}
	_refresh_setting_buttons()


## Undo: remaining uses shown as a badge; disabled when nothing to undo or
## no uses left.
func set_undo_state(can_undo: bool, remaining: int) -> void:
	_undo_button.badge_text = str(remaining)
	set_undo_enabled(can_undo and remaining > 0)


## Hint badge: free hints left this level + owned Hint boosters, shown as
## "1+2" when both exist (∞ in debug). Dimmed when nothing is available.
func set_hint_state(remaining: int, allowed: int, unlimited: bool, owned: int = 0) -> void:
	if unlimited:
		_hint_button.badge_text = "∞"
	elif remaining > 0 and owned > 0:
		_hint_button.badge_text = "%d+%d" % [remaining, owned]
	else:
		_hint_button.badge_text = str(remaining + owned)
	_hint_button.modulate.a = 1.0 if (unlimited or remaining + owned > 0) else 0.5


## Hammer badge = owned Hammer boosters; highlighted while aiming.
func set_hammer_state(owned: int, active: bool, usable: bool) -> void:
	_hammer_button.badge_text = str(owned)
	_hammer_button.modulate.a = 1.0 if owned > 0 and usable else 0.5
	_hammer_button.text = "CANCEL" if active else "HAMMER"


## Coins currently flying to the counter: the counter waits for them, so
## it counts up when they land rather than before.
var _coins_flying := 0
var _coins_pending := -1


func set_coins(coins: int, animate: bool = true) -> void:
	if _coins_flying > 0:
		_coins_pending = coins
		return
	_coin_pill.set_coins(coins, animate)


## HUD TOTAL SCORE (sum of every level's best; never goes down).
func set_total_score(total: int) -> void:
	_hud_total_value.text = _fmt(total)


func hud_total_text() -> String:
	return "%s %s" % [_hud_total_caption.text, _hud_total_value.text]


func open_shop(coins: int, inventory: Dictionary) -> void:
	_shop.open(coins, inventory)


func refresh_shop(coins: int, inventory: Dictionary) -> void:
	_shop.refresh(coins, inventory)


func is_shop_open() -> bool:
	return _shop.visible


func pulse_coins() -> void:
	_pulse(_coin_pill)


func show_title(has_progress: bool, level: int, stars: int, coins: int, total_score: int = 0) -> void:
	_title.open(has_progress, level, stars, coins, theme, total_score)
	set_total_score(total_score)
	_top.modulate.a = 0.0
	_bottom.modulate.a = 0.0


func hide_title() -> void:
	_title.close()
	_top.modulate.a = 1.0
	_bottom.modulate.a = 1.0


func is_title_open() -> bool:
	return _title.visible


## HUD colors follow the Chapter (block hues and buttons never change).
func apply_theme(t: Dictionary) -> void:
	theme = t
	_level_label.add_theme_color_override("font_color", t["text"])
	_name_label.add_theme_color_override("font_color", t["text_soft"])
	_hearts.empty_color = Color(1, 1, 1, 0.22) if t["dark"] else Palette.SLOT
	_hearts.queue_redraw()
	_progress.track_color = Color(1, 1, 1, 0.16) if t["dark"] else t["slot"]
	_progress.fill_color = t["accent"]
	_progress.queue_redraw()
	TutorialHint.text_color = t["text"]
	# Accent-colored surfaces follow the Chapter too.
	var accent_btn: Color = t["accent"].darkened(0.1) if t["dark"] else t["accent"]
	_next_button.set_background(accent_btn)
	_coin_pill.accent = t["accent"]
	_hud_total_caption.add_theme_color_override("font_color", t["text_soft"])
	_hud_total_value.add_theme_color_override("font_color", t["text"])
	_chain_label.add_theme_color_override("font_color", t["accent"])


## "CHAPTER 3 · DEEP CURRENT" banner when entering a new Chapter.
func show_chapter_banner(text: String) -> void:
	var vis := get_viewport().get_visible_rect()
	_banner.text = text
	_banner.add_theme_color_override("font_color", theme["accent"])
	_banner.visible = true
	# Long titles ("SECOND ERA" + a Chapter name) shrink to fit the screen.
	var fs := 44
	_banner.add_theme_font_size_override("font_size", fs)
	_banner.reset_size()
	while _banner.size.x > vis.size.x - 40.0 and fs > 26:
		fs -= 2
		_banner.add_theme_font_size_override("font_size", fs)
		_banner.reset_size()
	_banner.position = Vector2((vis.size.x - _banner.size.x) * 0.5, vis.size.y * 0.30)
	_banner.modulate.a = 0.0
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(0.8, 0.8)
	var t := create_tween()
	t.tween_property(_banner, "modulate:a", 1.0, 0.25)
	t.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(1.3)
	t.tween_property(_banner, "modulate:a", 0.0, 0.4)
	t.tween_callback(func(): _banner.visible = false)


func open_level_select(chapters: Array, total_stars: int, max_stars: int, current_chapter: int, total_score: int = 0) -> void:
	_level_select.open(chapters, total_stars, max_stars, current_chapter, total_score)


func show_chapter_card(summary: Dictionary) -> void:
	hide_complete()
	_bottom.modulate.a = 0.0
	_chapter_card.open(summary)


func refresh_chapter_card(summary: Dictionary) -> void:
	_chapter_card.refresh(summary)


func is_chapter_card_open() -> bool:
	return _chapter_card.visible


func chapter_card_chapter() -> int:
	return _chapter_card.chapter


## "+15 COINS" pops at a reward block and flies into the coin counter,
## which then counts up. Fast (~0.8 s) and never blocks input.
func fly_coins(from: Vector2, amount: int, rarity: int, new_total: int) -> void:
	var metal: Array = Palette.METALS[clampi(rarity, 1, Palette.METALS.size() - 1)]
	var l := _make_label(34, metal[1], 900)
	l.text = "+%d COINS" % amount
	l.add_theme_color_override("font_outline_color", metal[2])
	l.add_theme_constant_override("outline_size", 10)
	l.z_index = 50
	_root.add_child(l)
	l.reset_size()
	l.position = from - l.size * 0.5
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.6, 0.6)
	var target := _coin_pill.get_global_rect().get_center() - l.size * 0.5
	_coins_flying += 1
	if _coins_pending == -1:
		_coins_pending = new_total
	var t := l.create_tween()
	t.tween_property(l, "scale", Vector2(1.15, 1.15), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "position:y", l.position.y - 40.0, 0.18).set_trans(Tween.TRANS_SINE)
	t.tween_property(l, "position", target, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(l, "scale", Vector2(0.45, 0.45), 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		_coins_flying -= 1
		if _coins_flying == 0:
			# The latest balance wins (it may include more than this fly).
			var latest := _coins_pending if _coins_pending != -1 else new_total
			_coins_pending = -1
			set_coins(latest)
		l.queue_free())


func is_level_select_open() -> bool:
	return _level_select.visible


func set_undo_enabled(enabled: bool) -> void:
	_undo_button.disabled = not enabled
	_undo_button.queue_redraw()


## Shows "CHAIN xN" from x2 upward. Bigger and warmer as the chain grows.
func show_chain(chain: int) -> void:
	if _chain_tween:
		_chain_tween.kill()
	if chain < 2:
		_chain_tween = create_tween()
		_chain_tween.tween_property(_chain_label, "modulate:a", 0.0, 0.15)
		return
	var tier := mini(chain - 2, 8)
	_chain_label.text = "CHAIN x%d" % chain
	_chain_label.add_theme_font_size_override("font_size", 40 + tier * 3)
	_chain_label.add_theme_color_override("font_color", Color(theme["accent"]).lerp(Palette.ACCENT_HOT, tier / 8.0))
	_chain_label.pivot_offset = _chain_label.size * 0.5
	_chain_label.modulate.a = 1.0
	_chain_label.scale = Vector2.ONE * (1.25 + tier * 0.02)
	_chain_tween = create_tween()
	_chain_tween.tween_property(_chain_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Fade after a short idle so the screen stays clean between moves.
	_chain_tween.tween_interval(1.4)
	_chain_tween.tween_property(_chain_label, "modulate:a", 0.0, 0.3)


## `r`: settled result + score, stars, best, new_best, first_clear,
## hearts_left, max_hearts, undos, hints, perfect, is_last.
func show_complete(r: Dictionary) -> void:
	var perfect: bool = r["perfect"]
	_card_title.text = "PERFECT!" if perfect else "LEVEL COMPLETE"
	if r.get("master", false):
		_card_title.text = "GRAND MASTER!" if r.get("level", 0) > Chapters.master_level() else "MASTER CLEARED!"
	elif r.get("milestone", false):
		_card_title.text = "MILESTONE CLEARED!"
	_card_title.add_theme_color_override("font_color", Palette.GOLD if perfect else Palette.TEXT)
	_card_style.border_color = Palette.GOLD
	_card_style.set_border_width_all(8 if perfect else 0)
	_set_card_mode(true)
	_card_stars.set_stars(r["stars"], true)
	var hearts_txt := "HEARTS %d/%d" % [r["hearts_left"], r["max_hearts"]] if r["max_hearts"] > 0 else "NO HEARTS"
	_card_stats.text = "%s   ·   UNDO %d   ·   HINTS %d" % [hearts_txt, r["undos"], r["hints"]]
	if r.get("hammers", 0) > 0:
		_card_stats.text += "   ·   HAMMER %d" % r["hammers"]
	var coins: int = r.get("coins", 0)
	_card_coins.text = ("+%d COINS" % coins) if coins > 0 else ""
	if r.get("coin_notes", "") != "":
		_card_coins.text += "   (" + r["coin_notes"] + ")"
	_card_coins.visible = coins > 0
	if r["new_best"]:
		_card_reward.text = "NEW BEST!"
		_card_reward.add_theme_color_override("font_color", Palette.ACCENT)
	else:
		_card_reward.text = "LEVEL BEST  %s" % _fmt(r["best"])
		_card_reward.add_theme_color_override("font_color", Palette.TEXT_SOFT)
	# TOTAL SCORE only ever grows: it rises by the improvement over this
	# level's previous best, and stays put on a worse run or a replay.
	var total_after: int = r.get("total_after", 0)
	var total_before: int = mini(r.get("total_before", total_after), total_after)
	var gain: int = r.get("total_gain", 0)
	_card_score.text = _fmt(total_before)
	_card_gain.text = ("+%s" % _fmt(gain)) if gain > 0 else ""
	_card_gain.visible = gain > 0
	_card_total.text = "LEVEL SCORE  %s" % _fmt(r["score"])
	set_total_score(total_after)
	_next_button.text = "NEXT LEVEL" if not r["is_last"] else "PLAY AGAIN"
	if r.get("chapter_complete", 0) > 0:
		_next_button.text = "CONTINUE"  # opens the Chapter Complete card
	_overlay.visible = true
	_overlay.color = Color(theme["bg_bottom"], 0.0)
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.85, 0.85)
	_card.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_overlay, "color:a", 0.72, 0.25)
	t.tween_property(_card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_card, "modulate:a", 1.0, 0.18)
	# TOTAL SCORE counts up from the previous total by this run's gain -
	# never from 0, so the big number can only ever rise. NEW BEST pulses
	# after it lands.
	if _card_count and _card_count.is_valid():
		_card_count.kill()
	var c := create_tween()
	_card_count = c
	c.tween_method(func(v): _card_score.text = _fmt(int(v)), float(total_before), float(total_after), 0.6).set_delay(0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	c.tween_callback(func(): _card_score.text = _fmt(total_after))
	if r["new_best"]:
		_card_reward.pivot_offset = _card_reward.size * 0.5
		c.tween_callback(func(): AudioManager.play_new_best())
		c.tween_property(_card_reward, "scale", Vector2(1.25, 1.25), 0.12)
		c.tween_property(_card_reward, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	_bottom.modulate.a = 0.0


## Big golden stamp over the board before the card appears
## ("PERFECT!", or "MASTER!" for Level 100).
func show_perfect_stamp(text: String = "PERFECT!", hold: float = 0.45) -> void:
	var vis := get_viewport().get_visible_rect()
	_stamp.text = text
	_stamp.visible = true
	_stamp.reset_size()
	_stamp.position = vis.size * 0.5 - _stamp.size * 0.5
	_stamp.pivot_offset = _stamp.size * 0.5
	_stamp.scale = Vector2(2.2, 2.2)
	_stamp.rotation = -0.25
	_stamp.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_stamp, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_stamp, "rotation", -0.08, 0.28)
	t.tween_property(_stamp, "modulate:a", 1.0, 0.12)
	t.chain().tween_interval(hold)
	t.chain().tween_property(_stamp, "modulate:a", 0.0, 0.2)
	t.chain().tween_callback(func(): _stamp.visible = false)


static func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


func _set_card_mode(complete: bool) -> void:
	_card_coins.visible = complete and _card_coins.text != ""
	_card_stars.visible = complete
	_card_score.visible = complete
	_card_score_caption.visible = complete
	_card_gain.visible = complete and _card_gain.text != ""
	_card_total.visible = complete
	_card_reward.visible = complete
	_card_buttons.visible = complete


## Short, friendly out-of-hearts state. GameManager restarts the level after.
func show_try_again() -> void:
	_card_title.text = "OUT OF HEARTS"
	_card_title.add_theme_color_override("font_color", Palette.TEXT)
	_card_style.set_border_width_all(0)
	_card_stats.text = "No worries - try again!"
	_set_card_mode(false)
	_overlay.visible = true
	_overlay.color = Color(theme["bg_bottom"], 0.0)
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.9, 0.9)
	_card.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_overlay, "color:a", 0.6, 0.2)
	t.tween_property(_card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_card, "modulate:a", 1.0, 0.15)


func hide_complete() -> void:
	_overlay.visible = false
	_bottom.modulate.a = 1.0


func is_complete_visible() -> bool:
	return _overlay.visible


# --- Construction ----------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Top: title, level name, progress, chain.
	_top = VBoxContainer.new()
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_theme_constant_override("separation", 6)
	_root.add_child(_top)

	_level_label = _make_label(64, Palette.TEXT, 900)
	_level_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_level_label.gui_input.connect(_on_title_input)
	_top.add_child(_level_label)
	_name_label = _make_label(24, Palette.TEXT_SOFT, 800)
	_top.add_child(_name_label)

	var bar_holder := CenterContainer.new()
	bar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_holder.custom_minimum_size = Vector2(0, 30)
	_progress = BoardProgress.new()
	_progress.custom_minimum_size = Vector2(260, 10)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_holder.add_child(_progress)
	_top.add_child(bar_holder)

	_hearts_holder = CenterContainer.new()
	_hearts_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hearts = HeartsBar.new()
	_hearts_holder.add_child(_hearts)
	_top.add_child(_hearts_holder)

	_chain_label = _make_label(40, Palette.ACCENT, 900)
	_chain_label.custom_minimum_size = Vector2(0, 64)
	_chain_label.modulate.a = 0.0
	_top.add_child(_chain_label)

	# Bottom: Undo + Restart.
	_bottom = HBoxContainer.new()
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	_bottom.add_theme_constant_override("separation", 14)
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bottom)
	_undo_button = PillButton.new("UNDO", PillButton.Icon.UNDO, Palette.WHITE, Palette.TEXT, 20, true, true)
	_undo_button.custom_minimum_size = Vector2(150, 104)
	_undo_button.pressed.connect(func(): undo_pressed.emit())
	_bottom.add_child(_undo_button)
	_hint_button = PillButton.new("HINT", PillButton.Icon.HINT, Palette.WHITE, Palette.TEXT, 20, true, true)
	_hint_button.custom_minimum_size = Vector2(150, 104)
	_hint_button.pressed.connect(func(): hint_pressed.emit())
	_bottom.add_child(_hint_button)
	_hammer_button = PillButton.new("HAMMER", PillButton.Icon.HAMMER, Palette.WHITE, Palette.TEXT, 20, true, true)
	_hammer_button.custom_minimum_size = Vector2(150, 104)
	_hammer_button.pressed.connect(func(): hammer_pressed.emit())
	_bottom.add_child(_hammer_button)
	_restart_button = PillButton.new("RESTART", PillButton.Icon.RESTART, Palette.WHITE, Palette.TEXT, 20, true, true)
	_restart_button.custom_minimum_size = Vector2(150, 104)
	_restart_button.pressed.connect(func(): restart_pressed.emit())
	_bottom.add_child(_restart_button)

	# Level complete overlay.
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	_root.add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	_card = PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Palette.WHITE
	card_style.set_corner_radius_all(44)
	card_style.anti_aliasing = true
	card_style.shadow_color = Palette.SHADOW
	card_style.shadow_size = 24
	card_style.shadow_offset = Vector2(0, 8)
	card_style.set_content_margin_all(40)
	_card_style = card_style
	_card.add_theme_stylebox_override("panel", card_style)
	_card.custom_minimum_size = Vector2(600, 0)
	center.add_child(_card)
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 18)
	_card.add_child(card_box)
	_card_title = _make_label(50, Palette.TEXT, 900)
	card_box.add_child(_card_title)
	_card_stars = StarsRow.new(36)
	_card_stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_box.add_child(_card_stars)
	_card_score_caption = _make_label(22, Palette.TEXT_SOFT, 900)
	_card_score_caption.text = "TOTAL SCORE"
	card_box.add_child(_card_score_caption)
	_card_score = _make_label(64, Palette.TEXT, 900)
	card_box.add_child(_card_score)
	_card_gain = _make_label(26, Palette.ACCENT, 900)
	card_box.add_child(_card_gain)
	_card_total = _make_label(28, Palette.TEXT, 900)
	card_box.add_child(_card_total)
	_card_reward = _make_label(24, Palette.ACCENT, 900)
	card_box.add_child(_card_reward)
	_card_stats = _make_label(22, Palette.TEXT_SOFT, 800)
	_card_coins = _make_label(26, Color("#D98A00"), 900)
	_card_coins.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_coins.custom_minimum_size = Vector2(520, 0)
	card_box.add_child(_card_stats)
	card_box.add_child(_card_coins)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	card_box.add_child(spacer)
	_card_buttons = HBoxContainer.new()
	_card_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_buttons.add_theme_constant_override("separation", 16)
	card_box.add_child(_card_buttons)
	_replay_button = PillButton.new("REPLAY", PillButton.Icon.RESTART, Palette.BACKGROUND, Palette.TEXT, 28, true)
	_replay_button.custom_minimum_size = Vector2(200, 104)
	_replay_button.pressed.connect(func(): replay_pressed.emit())
	_card_buttons.add_child(_replay_button)
	_next_button = PillButton.new("NEXT LEVEL", PillButton.Icon.NONE, Palette.ACCENT, Palette.WHITE, 32)
	_next_button.custom_minimum_size = Vector2(300, 104)
	_next_button.pressed.connect(func(): next_pressed.emit())
	_card_buttons.add_child(_next_button)

	_stamp = _make_label(110, Palette.GOLD, 900)
	_stamp.text = "PERFECT!"
	_stamp.add_theme_color_override("font_outline_color", Palette.WHITE)
	_stamp.add_theme_constant_override("outline_size", 18)
	_stamp.visible = false
	_root.add_child(_stamp)

	# Settings: gear in the top-right corner + a small card of toggles.
	_settings_button = PillButton.new("", PillButton.Icon.GEAR, Palette.WHITE, Palette.TEXT_SOFT, 26)
	_settings_button.custom_minimum_size = Vector2(76, 76)
	_settings_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_settings_button.pressed.connect(_open_settings)
	_root.add_child(_settings_button)
	_levels_button = PillButton.new("", PillButton.Icon.GRID, Palette.WHITE, Palette.TEXT_SOFT, 26)
	_levels_button.custom_minimum_size = Vector2(76, 76)
	_levels_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_levels_button.pressed.connect(func(): levels_opened.emit())
	_root.add_child(_levels_button)
	_build_settings()
	_level_select = LevelSelect.new()
	_level_select.level_chosen.connect(func(n): level_chosen.emit(n))
	_level_select.chest_claim.connect(func(c, t): chest_claim.emit(c, t))
	_coin_pill = CoinPill.new()
	_coin_pill.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_coin_pill.pressed.connect(func(): shop_open_requested.emit())
	_root.add_child(_coin_pill)
	_hud_total = VBoxContainer.new()
	_hud_total.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_hud_total.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_total.add_theme_constant_override("separation", -4)
	_hud_total_caption = _make_label(15, Palette.TEXT_SOFT, 900)
	_hud_total_caption.text = "TOTAL SCORE"
	_hud_total_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hud_total.add_child(_hud_total_caption)
	_hud_total_value = _make_label(26, Palette.TEXT, 900)
	_hud_total_value.text = "0"
	_hud_total_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hud_total.add_child(_hud_total_value)
	_root.add_child(_hud_total)
	_banner = _make_label(44, Palette.ACCENT, 900)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.visible = false
	_root.add_child(_banner)
	_title = TitleScreen.new()
	_title.continue_pressed.connect(func(): continue_pressed.emit())
	_title.level_select_pressed.connect(func(): title_level_select.emit())
	_root.add_child(_title)
	_root.add_child(_level_select)
	_chapter_card = ChapterCard.new()
	_chapter_card.continue_pressed.connect(func():
		_bottom.modulate.a = 1.0
		chapter_continue.emit())
	_chapter_card.chest_claim.connect(func(c, t): chest_claim.emit(c, t))
	_root.add_child(_chapter_card)
	_shop = ShopPanel.new()
	_shop.buy_requested.connect(func(item): buy_requested.emit(item))
	_root.add_child(_shop)
	_build_recovery()


func _build_settings() -> void:
	_settings_overlay = ColorRect.new()
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.color = Color(Palette.TEXT, 0.35)
	_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.visible = false
	_settings_overlay.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close_settings())
	_root.add_child(_settings_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_overlay.add_child(center)
	var card := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Palette.WHITE
	st.set_corner_radius_all(40)
	st.anti_aliasing = true
	st.set_content_margin_all(40)
	card.add_theme_stylebox_override("panel", st)
	card.custom_minimum_size = Vector2(480, 0)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)
	box.add_child(_make_label(40, Palette.TEXT, 900))
	box.get_child(0).text = "SETTINGS"
	for key in ["music", "sfx", "haptics"]:
		var b := PillButton.new("", PillButton.Icon.NONE, Palette.BACKGROUND, Palette.TEXT, 28)
		b.custom_minimum_size = Vector2(0, 84)
		b.pressed.connect(func():
			_settings[key] = not _settings[key]
			_refresh_setting_buttons()
			setting_toggled.emit(key, _settings[key]))
		box.add_child(b)
		_setting_buttons[key] = b
	# Save safety (v0.5.2): a copyable code with the whole save, and restore.
	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 12)
	box.add_child(save_row)
	var backup := PillButton.new("BACKUP CODE", PillButton.Icon.NONE, Palette.BACKGROUND, Palette.TEXT, 22)
	_backup_button = backup
	backup.custom_minimum_size = Vector2(0, 76)
	backup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backup.pressed.connect(func():
		_close_settings()
		backup_requested.emit())
	save_row.add_child(backup)
	var restore := PillButton.new("RESTORE", PillButton.Icon.NONE, Palette.BACKGROUND, Palette.TEXT, 22)
	_restore_button = restore
	restore.custom_minimum_size = Vector2(0, 76)
	restore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restore.pressed.connect(func():
		_close_settings()
		restore_requested.emit())
	save_row.add_child(restore)
	var done := PillButton.new("DONE", PillButton.Icon.NONE, Palette.ACCENT, Palette.WHITE, 30)
	done.custom_minimum_size = Vector2(0, 90)
	done.pressed.connect(_close_settings)
	box.add_child(done)
	_refresh_setting_buttons()


# --- Recovery (v0.5.2) ---------------------------------------------------------

var _recovery: ColorRect
var _recovery_text: Label
var _recovery_new: PillButton
var _recovery_restore: PillButton
var _backup_button: PillButton
var _restore_button: PillButton
var _recovery_confirm := false


func _build_recovery() -> void:
	_recovery = ColorRect.new()
	_recovery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_recovery.color = Color(Palette.TEXT, 0.55)
	_recovery.mouse_filter = Control.MOUSE_FILTER_STOP
	_recovery.visible = false
	_root.add_child(_recovery)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_recovery.add_child(center)
	var card := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Palette.WHITE
	st.set_corner_radius_all(40)
	st.anti_aliasing = true
	st.set_content_margin_all(36)
	card.add_theme_stylebox_override("panel", st)
	card.custom_minimum_size = Vector2(600, 0)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)
	var title := _make_label(38, Palette.TEXT, 900)
	title.text = "SAVED PROGRESS"
	box.add_child(title)
	_recovery_text = _make_label(24, Palette.TEXT_SOFT, 800)
	_recovery_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recovery_text.custom_minimum_size = Vector2(520, 0)
	box.add_child(_recovery_text)
	var restore := PillButton.new("RESTORE FROM BACKUP CODE", PillButton.Icon.NONE, Palette.ACCENT, Palette.WHITE, 26)
	restore.custom_minimum_size = Vector2(0, 92)
	restore.pressed.connect(func(): restore_requested.emit())
	box.add_child(restore)
	_recovery_restore = restore
	_recovery_new = PillButton.new("", PillButton.Icon.NONE, Palette.BACKGROUND, Palette.TEXT, 24)
	_recovery_new.custom_minimum_size = Vector2(0, 84)
	_recovery_new.pressed.connect(func():
		# Two taps: starting over is never one accidental tap away.
		if not _recovery_confirm:
			_recovery_confirm = true
			_recovery_new.text = "TAP AGAIN TO START OVER"
			return
		hide_recovery()
		recovery_new_game.emit())
	box.add_child(_recovery_new)


func show_recovery(text: String) -> void:
	_recovery_text.text = text
	_recovery_confirm = false
	_recovery_new.text = "START NEW GAME"
	_recovery.visible = true


func hide_recovery() -> void:
	_recovery.visible = false


func is_recovery_open() -> bool:
	return _recovery.visible


## Title-screen save diagnostic (testing on real devices).
func set_save_diagnostic(text: String) -> void:
	_title.set_diagnostic(text)


func _refresh_setting_buttons() -> void:
	var names := {"music": "MUSIC", "sfx": "SOUND EFFECTS", "haptics": "VIBRATION"}
	for key in _setting_buttons:
		_setting_buttons[key].text = "%s:  %s" % [names[key], "ON" if _settings[key] else "OFF"]
		_setting_buttons[key].modulate.a = 1.0 if _settings[key] else 0.6


func _open_settings() -> void:
	_settings_overlay.visible = true


func _close_settings() -> void:
	_settings_overlay.visible = false


func is_settings_open() -> bool:
	return _settings_overlay.visible


func _make_label(font_size: int, color: Color, weight: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Palette.font(weight))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## Respect notches / home indicators on phones.
func _apply_safe_area() -> void:
	_safe_top = 0.0
	_safe_bottom = 0.0
	if OS.has_feature("mobile"):
		var win := Vector2(DisplayServer.window_get_size())
		var safe := Rect2(DisplayServer.get_display_safe_area())
		var scale_y := get_viewport().get_visible_rect().size.y / maxf(win.y, 1.0)
		_safe_top = safe.position.y * scale_y
		_safe_bottom = maxf(0.0, (win.y - safe.end.y) * scale_y)
	_top.offset_top = _safe_top + 36.0
	_settings_button.offset_left = -76.0 - 24.0
	_settings_button.offset_right = -24.0
	_settings_button.offset_top = _safe_top + 28.0
	_settings_button.offset_bottom = _safe_top + 28.0 + 76.0
	_levels_button.offset_left = 24.0
	_levels_button.offset_right = 24.0 + 76.0
	_levels_button.offset_top = _safe_top + 28.0
	_levels_button.offset_bottom = _safe_top + 28.0 + 76.0
	if _hud_total:
		_hud_total.offset_left = 30.0
		_hud_total.offset_right = 30.0 + 190.0
		_hud_total.offset_top = _safe_top + 148.0
		_hud_total.offset_bottom = _safe_top + 148.0 + 60.0
	if _coin_pill:
		_coin_pill.offset_left = -150.0 - 24.0
		_coin_pill.offset_right = -24.0
		_coin_pill.offset_top = _safe_top + 150.0
		_coin_pill.offset_bottom = _safe_top + 150.0 + 56.0
	_bottom.offset_top = -BOTTOM_HEIGHT - _safe_bottom + 30.0
	_bottom.offset_bottom = -_safe_bottom - 60.0


func _on_title_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		title_tapped.emit()
