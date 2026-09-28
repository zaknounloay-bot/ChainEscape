class_name ChapterCard
extends ColorRect
## "CHAPTER 4 COMPLETE" moment (v0.5). Shown once per Chapter, between the
## last level card and the next Chapter. Short by design: the Chapter's
## stars (out of 30), coins earned, PERFECT levels and reward blocks found,
## the Chapter chest (claim tiers right here) and a preview of what comes
## next, drawn in the next Chapter's own colors to build anticipation.

signal continue_pressed
signal chest_claim(chapter: int, tier: int)

var chapter: int = 0
var _card: PanelContainer
var _card_style := StyleBoxFlat.new()
var _kicker: Label
var _title: Label
var _name: Label
var _stars: Label
var _bar: BoardProgress
var _stats: Label
var _chest_row: HBoxContainer
var _chest_label: Label
var _preview: PanelContainer
var _preview_style := StyleBoxFlat.new()
var _next_title: Label
var _next_new: Label
var _continue: PillButton


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card = PanelContainer.new()
	_card_style.bg_color = Palette.WHITE
	_card_style.set_corner_radius_all(44)
	_card_style.anti_aliasing = true
	_card_style.shadow_color = Palette.SHADOW
	_card_style.shadow_size = 24
	_card_style.set_content_margin_all(36)
	_card.add_theme_stylebox_override("panel", _card_style)
	_card.custom_minimum_size = Vector2(620, 0)
	center.add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_card.add_child(box)
	_kicker = _label(26, Palette.TEXT_SOFT)
	box.add_child(_kicker)
	_title = _label(58, Palette.TEXT)
	_title.text = "COMPLETE!"
	box.add_child(_title)
	_name = _label(26, Palette.TEXT_SOFT)
	box.add_child(_name)
	_stars = _label(44, Palette.GOLD)
	box.add_child(_stars)
	var bar_holder := CenterContainer.new()
	_bar = BoardProgress.new()
	_bar.custom_minimum_size = Vector2(420, 14)
	bar_holder.add_child(_bar)
	box.add_child(bar_holder)
	_stats = _label(22, Palette.TEXT_SOFT)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats.custom_minimum_size = Vector2(540, 0)
	box.add_child(_stats)
	_chest_label = _label(22, Palette.TEXT)
	box.add_child(_chest_label)
	_chest_row = HBoxContainer.new()
	_chest_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_chest_row.add_theme_constant_override("separation", 10)
	box.add_child(_chest_row)
	_preview = PanelContainer.new()
	_preview_style.set_corner_radius_all(26)
	_preview_style.set_content_margin_all(18)
	_preview_style.anti_aliasing = true
	_preview.add_theme_stylebox_override("panel", _preview_style)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 4)
	_preview.add_child(pv)
	var up := _label(18, Palette.TEXT_SOFT)
	up.text = "UP NEXT"
	up.name = "UpNext"
	pv.add_child(up)
	_next_title = _label(28, Palette.TEXT)
	pv.add_child(_next_title)
	_next_new = _label(20, Palette.GOLD)
	pv.add_child(_next_new)
	box.add_child(_preview)
	_continue = PillButton.new("CONTINUE", PillButton.Icon.NONE, Palette.ACCENT, Palette.WHITE, 32)
	_continue.custom_minimum_size = Vector2(0, 100)
	_continue.pressed.connect(func():
		close()
		continue_pressed.emit())
	box.add_child(_continue)


## `s`: GameManager.chapter_summary(chapter).
func open(s: Dictionary) -> void:
	chapter = s["chapter"]
	var t: Dictionary = s["theme"]
	color = Color(t["bg_bottom"], 0.0)
	_kicker.text = "CHAPTER %d" % chapter
	_name.text = String(t["name"]).to_upper()
	_title.add_theme_color_override("font_color", t["accent"].darkened(0.15) if not t["dark"] else t["accent"].darkened(0.35))
	_bar.fill_color = Palette.GOLD
	_bar.track_color = Palette.SLOT
	refresh(s)
	visible = true
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.85, 0.85)
	_card.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "color:a", 0.78, 0.25)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "modulate:a", 1.0, 0.18)


func refresh(s: Dictionary) -> void:
	_stars.text = "★ %d / %d" % [s["stars"], s["max_stars"]]
	_bar.set_progress(float(s["stars"]) / maxf(s["max_stars"], 1.0), false)
	# TOTAL SCORE (all levels) first, so the Chapter's own sum is never
	# mistaken for it.
	var parts := ["TOTAL SCORE %s" % UIManager._fmt(s.get("total_score", 0)), "CHAPTER SCORE %s" % UIManager._fmt(s["score"]),"COINS EARNED %d" % s["coins"], "PERFECT %d/%d" % [s["perfect"], s["levels"]]]
	if s["rewards_total"] > 0:
		parts.append("SILVER/GOLD %d/%d" % [s["rewards_got"], s["rewards_total"]])
	_stats.text = "   ·   ".join(parts)
	_build_chests(s["tiers"])
	var nt: Dictionary = s["next_theme"]
	if s["next_title"] != "":
		_next_title.text = s["next_title"]
		_next_new.text = s["next_new"]
		_next_new.visible = s["next_new"] != ""
		_preview_style.bg_color = nt["bg_bottom"] if nt["dark"] else nt["bg_top"].lerp(nt["bg_bottom"], 0.5)
		_preview_style.border_color = nt["accent"]
		_preview_style.set_border_width_all(4)
		_next_title.add_theme_color_override("font_color", nt["text"])
		_preview.get_child(0).get_node("UpNext").add_theme_color_override("font_color", nt["text_soft"])
		_next_new.add_theme_color_override("font_color", nt["accent"])
		_continue.set_background(nt["accent"].darkened(0.1) if nt["dark"] else nt["accent"])
		_continue.text = "CONTINUE"
	else:
		_next_title.text = "More Chapters are coming"
		_next_new.visible = false
		_preview_style.bg_color = Palette.BACKGROUND
		_preview_style.set_border_width_all(0)
		_next_title.add_theme_color_override("font_color", Palette.TEXT)
		_continue.set_background(Palette.ACCENT)
		_continue.text = "PLAY AGAIN"


func _build_chests(tiers: Array) -> void:
	for c in _chest_row.get_children():
		c.queue_free()
	var reached := -1
	for i in tiers.size():
		if tiers[i]["claimed"] or tiers[i]["claimable"]:
			reached = i
	_chest_label.text = "CHAPTER CHEST" if reached == -1 else "CHAPTER CHEST  ·  %s" % String(tiers[reached]["name"]).to_upper()
	for i in tiers.size():
		_chest_row.add_child(LevelSelect.chest_button(chapter, i, tiers[i], func(): chest_claim.emit(chapter, i)))


func close() -> void:
	visible = false


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Palette.font(900))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l
