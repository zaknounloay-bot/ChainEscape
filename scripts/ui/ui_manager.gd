class_name UIManager
extends CanvasLayer
## Gameplay HUD: level title, board progress, chain counter, Undo/Restart and
## the level-complete card. Emits intent signals; never touches game state.

signal undo_pressed
signal restart_pressed
signal next_pressed
signal title_tapped  # used as a hidden debug gesture on devices

const TOP_HEIGHT := 250.0
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


func show_complete(best_chain: int, perfect: bool, is_last_level: bool) -> void:
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

	_chain_label = _make_label(40, Palette.ACCENT, 900)
	_chain_label.custom_minimum_size = Vector2(0, 64)
	_chain_label.modulate.a = 0.0
	_top.add_child(_chain_label)

	# Bottom: Undo + Restart.
	_bottom = HBoxContainer.new()
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	_bottom.add_theme_constant_override("separation", 28)
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bottom)
	_undo_button = PillButton.new("UNDO", PillButton.Icon.UNDO)
	_undo_button.custom_minimum_size = Vector2(250, 100)
	_undo_button.pressed.connect(func(): undo_pressed.emit())
	_bottom.add_child(_undo_button)
	_restart_button = PillButton.new("RESTART", PillButton.Icon.RESTART)
	_restart_button.custom_minimum_size = Vector2(250, 100)
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
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	card_box.add_child(spacer)
	_next_button = PillButton.new("NEXT LEVEL", PillButton.Icon.NONE, Palette.ACCENT, Palette.WHITE, 36)
	_next_button.custom_minimum_size = Vector2(380, 112)
	_next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_next_button.pressed.connect(func(): next_pressed.emit())
	card_box.add_child(_next_button)


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
	_bottom.offset_top = -BOTTOM_HEIGHT - _safe_bottom + 30.0
	_bottom.offset_bottom = -_safe_bottom - 60.0


func _on_title_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		title_tapped.emit()
