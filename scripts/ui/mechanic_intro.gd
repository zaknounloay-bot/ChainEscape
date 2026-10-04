class_name MechanicIntro
extends CanvasLayer
## "NEW MECHANIC!" - a short card the FIRST time a new mechanic appears
## (levels 201+; Portal at level 201). About 1.8 s, then play starts; a tap
## skips it. Shown once per save (GameManager stores "intro_<mechanic>" in
## PlayerProgress.tips_seen) and never to a player already past that level.
##
## The card plays the mechanic in miniature (Portal: a block ENTERS A, comes
## out of the other A and CONTINUES). Reduced motion: the same picture,
## still. Every visible word comes from TEXT, one entry per mechanic, so it
## can be translated in one place.

signal finished

const TEXT := {
	"portal": {"badge": "NEW MECHANIC!", "name": "PORTAL", "steps": ["ENTER A", "EXIT A", "CONTINUE"]},
}
const HOLD := 1.8  # seconds before play starts by itself
const PORTAL_COLOR := Color("#00D8C4")
const BLOCK_COLOR := Color("#FF4D5E")

var mechanic := "portal"
var reduced := false
var _done := false
var _diagram: Diagram


func _init(p_mechanic: String = "portal", p_reduced: bool = false) -> void:
	layer = 4  # over the game UI, under Social (5) and the debug panel
	mechanic = p_mechanic if TEXT.has(p_mechanic) else "portal"
	reduced = p_reduced


func _ready() -> void:
	var t: Dictionary = TEXT[mechanic]
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(func(e):
		if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed):
			close())
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.12, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#14122A")
	style.set_corner_radius_all(36)
	style.border_color = PORTAL_COLOR
	style.set_border_width_all(4)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	card.add_theme_stylebox_override("panel", style)
	card.set_anchors_preset(Control.PRESET_CENTER)
	root.add_child(card)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	box.add_child(_label(t["badge"], 26, Color("#FFC43D")))
	box.add_child(_label(t["name"], 64, Color.WHITE))
	_diagram = Diagram.new()
	_diagram.custom_minimum_size = Vector2(560, 150)
	_diagram.steps = t["steps"]
	_diagram.reduced = reduced
	box.add_child(_diagram)
	card.reset_size()
	card.position = (get_viewport().get_visible_rect().size - card.size) * 0.5
	# Pop in (a fade only with reduced motion).
	card.pivot_offset = card.size * 0.5
	card.modulate.a = 0.0
	var tw := create_tween()
	if reduced:
		tw.tween_property(card, "modulate:a", 1.0, 0.15)
	else:
		card.scale = Vector2(0.85, 0.85)
		tw.tween_property(card, "modulate:a", 1.0, 0.12)
		tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not reduced:
		_diagram.play()
	get_tree().create_timer(HOLD).timeout.connect(close)
	AudioManager.play_portal()


## Ends the card (timer or tap); `finished` fires once.
func close() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.tween_property(get_child(0), "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		finished.emit()
		queue_free())


func is_done() -> bool:
	return _done


func _label(text: String, fs: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Palette.font(900))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The miniature: portal A (left), portal A (right), a block that goes in at
## the left one and comes out of the right one, and the three step words.
class Diagram extends Control:
	var steps: Array = []
	var reduced := false
	var t := 0.0  # 0..1 progress of the block's trip

	func play() -> void:
		var tw := create_tween()
		tw.tween_property(self, "t", 1.0, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var y := 52.0
		var a := Vector2(w * 0.30, y)
		var b := Vector2(w * 0.70, y)
		for p in [a, b]:
			draw_circle(p, 34.0, MechanicIntro.PORTAL_COLOR)
			draw_circle(p, 27.0, Color("#10121C"))
			draw_arc(p, 20.0, 0.0, TAU, 32, Color(MechanicIntro.PORTAL_COLOR, 0.55), 3.0, true)
		var font := Palette.font(900)
		for p in [a, b]:
			var s := font.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
			draw_string(font, p + Vector2(-s.x * 0.5, 9), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
		# Guide arrows: before A, between the portals (a dotted "jump"), after A.
		var faint := Color(1, 1, 1, 0.35)
		draw_line(Vector2(w * 0.05, y), a - Vector2(40, 0), faint, 3.0, true)
		for i in 5:
			var x := a.x + 44 + i * ((b.x - a.x - 88) / 4.0)
			draw_circle(Vector2(x, y), 3.0, faint)
		draw_line(b + Vector2(40, 0), Vector2(w * 0.95, y), faint, 3.0, true)
		# The travelling block.
		if reduced:
			_block(Vector2(w * 0.12, y), 1.0)
			_block(Vector2(w * 0.88, y), 1.0)
		else:
			var pos: Vector2
			var sc := 1.0
			if t < 0.42:
				pos = Vector2(w * 0.08, y).lerp(a, t / 0.42)
				sc = 1.0 - maxf(0.0, (t - 0.32) / 0.10) * 0.85
			elif t < 0.58:
				pos = b
				sc = 0.15 + (t - 0.42) / 0.16 * 0.85
			else:
				pos = b.lerp(Vector2(w * 0.96, y), (t - 0.58) / 0.42)
			_block(pos, clampf(sc, 0.15, 1.0))
		# Step words under the picture.
		var xs := [w * 0.30, w * 0.70, w * 0.92]
		for i in mini(steps.size(), 3):
			var txt: String = steps[i]
			var s := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
			var x: float = clampf(xs[i] - s.x * 0.5, 0.0, w - s.x)
			draw_string(font, Vector2(x, y + 76), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.92))

	func _block(at: Vector2, sc: float) -> void:
		var half := 24.0 * sc
		var r := Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0)
		var st := StyleBoxFlat.new()
		st.bg_color = MechanicIntro.BLOCK_COLOR
		st.set_corner_radius_all(int(10 * sc))
		st.draw(get_canvas_item(), r)
		if sc > 0.5:
			var h := 12.0 * sc
			draw_colored_polygon(PackedVector2Array([at + Vector2(h, 0), at + Vector2(-h * 0.4, -h * 0.8), at + Vector2(-h * 0.4, h * 0.8)]), Color.WHITE)
