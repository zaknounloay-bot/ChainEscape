class_name UIManager
extends CanvasLayer
## Gameplay HUD: level title, board progress, hearts, chain counter,
## Undo/Hint/Restart, settings and the level-complete / try-again card.
## Emits intent signals; never touches game state.

signal undo_pressed
signal restart_pressed
signal next_pressed
signal hint_pressed
signal setting_toggled(key: String, on: bool)  # "music" | "sfx" | "haptics"
signal title_tapped  # used as a hidden debug gesture on devices

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
var _card_reward: Label
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


func set_level(number: int, total: int, level_name: String) -> void:
	_level_label.text = "LEVEL %d" % number
	_name_label.text = level_name.to_upper() if total == 0 else "%s  ·  %d/%d" % [level_name.to_upper(), number, total]
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
	_chain_label.add_theme_color_override("font_color", Palette.ACCENT.lerp(Palette.ACCENT_HOT, tier / 8.0))
	_chain_label.pivot_offset = _chain_label.size * 0.5
	_chain_label.modulate.a = 1.0
	_chain_label.scale = Vector2.ONE * (1.25 + tier * 0.02)
	_chain_tween = create_tween()
	_chain_tween.tween_property(_chain_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Fade after a short idle so the screen stays clean between moves.
	_chain_tween.tween_interval(1.4)
	_chain_tween.tween_property(_chain_label, "modulate:a", 0.0, 0.3)


func show_complete(best_chain: int, perfect: bool, is_last_level: bool, hints_awarded: int = 0) -> void:
	_card_reward.visible = hints_awarded > 0
	_card_reward.text = "+%d HINT%s" % [hints_awarded, "S" if hints_awarded > 1 else ""]
	_next_button.visible = true
	_card_title.text = "LEVEL COMPLETE" if not is_last_level else "ALL LEVELS COMPLETE"
	var stats := "Best chain  x%d" % best_chain
	if perfect:
		stats = "PERFECT CHAIN!  ·  " + stats
	_card_stats.text = stats
	_next_button.text = "NEXT LEVEL" if not is_last_level else "PLAY AGAIN"
	_overlay.visible = true
	_overlay.color = Color(Palette.BACKGROUND, 0.0)
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.85, 0.85)
	_card.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_overlay, "color:a", 0.72, 0.25)
	t.tween_property(_card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_card, "modulate:a", 1.0, 0.18)
	_bottom.modulate.a = 0.0


## Short, friendly out-of-hearts state. GameManager restarts the level after.
func show_try_again() -> void:
	_card_title.text = "OUT OF HEARTS"
	_card_stats.text = "No worries - try again!"
	_card_reward.visible = false
	_next_button.visible = false
	_overlay.visible = true
	_overlay.color = Color(Palette.BACKGROUND, 0.0)
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
	_bottom.add_theme_constant_override("separation", 16)
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bottom)
	_undo_button = PillButton.new("UNDO", PillButton.Icon.UNDO, Palette.WHITE, Palette.TEXT, 26, true)
	_undo_button.custom_minimum_size = Vector2(200, 96)
	_undo_button.pressed.connect(func(): undo_pressed.emit())
	_bottom.add_child(_undo_button)
	_hint_button = PillButton.new("HINT", PillButton.Icon.HINT, Palette.WHITE, Palette.TEXT, 26, true)
	_hint_button.custom_minimum_size = Vector2(186, 96)
	_hint_button.pressed.connect(func(): hint_pressed.emit())
	_bottom.add_child(_hint_button)
	_restart_button = PillButton.new("RESTART", PillButton.Icon.RESTART, Palette.WHITE, Palette.TEXT, 26, true)
	_restart_button.custom_minimum_size = Vector2(212, 96)
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
	card_style.set_content_margin_all(48)
	_card.add_theme_stylebox_override("panel", card_style)
	_card.custom_minimum_size = Vector2(560, 0)
	center.add_child(_card)
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 18)
	_card.add_child(card_box)
	_card_title = _make_label(50, Palette.TEXT, 900)
	card_box.add_child(_card_title)
	_card_stats = _make_label(26, Palette.TEXT_SOFT, 800)
	card_box.add_child(_card_stats)
	_card_reward = _make_label(30, Palette.ACCENT, 900)
	_card_reward.visible = false
	card_box.add_child(_card_reward)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	card_box.add_child(spacer)
	_next_button = PillButton.new("NEXT LEVEL", PillButton.Icon.NONE, Palette.ACCENT, Palette.WHITE, 36)
	_next_button.custom_minimum_size = Vector2(380, 112)
	_next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_next_button.pressed.connect(func(): next_pressed.emit())
	card_box.add_child(_next_button)

	# Settings: gear in the top-right corner + a small card of toggles.
	_settings_button = PillButton.new("", PillButton.Icon.GEAR, Palette.WHITE, Palette.TEXT_SOFT, 26)
	_settings_button.custom_minimum_size = Vector2(76, 76)
	_settings_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_settings_button.pressed.connect(_open_settings)
	_root.add_child(_settings_button)
	_build_settings()


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
	var done := PillButton.new("DONE", PillButton.Icon.NONE, Palette.ACCENT, Palette.WHITE, 30)
	done.custom_minimum_size = Vector2(0, 90)
	done.pressed.connect(_close_settings)
	box.add_child(done)
	_refresh_setting_buttons()


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
	_bottom.offset_top = -BOTTOM_HEIGHT - _safe_bottom + 30.0
	_bottom.offset_bottom = -_safe_bottom - 60.0


func _on_title_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		title_tapped.emit()
