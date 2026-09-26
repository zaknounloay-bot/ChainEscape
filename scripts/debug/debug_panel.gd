class_name DebugPanel
extends CanvasLayer
## Developer-only overlay. Hidden by default.
##
## Open it with F1 on desktop, or tap the "LEVEL X" title 5 times quickly on a
## device. Launching with `-- --debug` also opens it.

signal level_requested(number: int)
signal restart_requested
signal coords_toggled(on: bool)
signal hint_requested  # play one correct move (solver)
signal solve_requested  # play the whole level automatically

var level_count: int = 1
var _panel: PanelContainer
var _spin: SpinBox
var _title_taps: Array[float] = []


func _ready() -> void:
	layer = 20
	_build()
	visible = "--debug" in OS.get_cmdline_user_args()


func toggle() -> void:
	visible = not visible


func set_current_level(number: int) -> void:
	if _spin:
		_spin.set_value_no_signal(number)


## Counts rapid taps on the title (the device gesture to open the panel).
func register_title_tap() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_title_taps.append(now)
	while not _title_taps.is_empty() and now - _title_taps[0] > 2.0:
		_title_taps.pop_front()
	if _title_taps.size() >= 5:
		_title_taps.clear()
		toggle()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		toggle()
	elif visible and event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R: restart_requested.emit()
			KEY_H: hint_requested.emit()
			KEY_S: solve_requested.emit()
			KEY_BRACKETLEFT: level_requested.emit(int(_spin.value) - 1)
			KEY_BRACKETRIGHT: level_requested.emit(int(_spin.value) + 1)


func _build() -> void:
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.14, 0.88)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.position = Vector2(12, 12)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "DEBUG (F1) - hints unlimited"
	title.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(title)

	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(_button("<", func(): level_requested.emit(int(_spin.value) - 1)))
	_spin = SpinBox.new()
	_spin.min_value = 1
	_spin.max_value = 99
	_spin.custom_minimum_size = Vector2(110, 0)
	row.add_child(_spin)
	row.add_child(_button(">", func(): level_requested.emit(int(_spin.value) + 1)))
	row.add_child(_button("Load", func(): level_requested.emit(int(_spin.value))))

	var row2 := HBoxContainer.new()
	box.add_child(row2)
	row2.add_child(_button("Restart", func(): restart_requested.emit()))
	row2.add_child(_button("Move", func(): hint_requested.emit()))
	row2.add_child(_button("Solve", func(): solve_requested.emit()))

	var coords := CheckBox.new()
	coords.text = "Show grid coords"
	coords.add_theme_color_override("font_color", Color.WHITE)
	coords.toggled.connect(func(on): coords_toggled.emit(on))
	box.add_child(coords)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(64, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b
