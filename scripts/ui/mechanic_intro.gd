class_name MechanicIntro
extends CanvasLayer
## "NEW MECHANIC!" - a short card the FIRST time a new mechanic appears
## (Portal at 201, Sequence at 226, Movable at 251). About 1.8 s (Movable,
## with its one extra line, 2.2 s), then play starts; a tap skips it. Shown
## once per save (GameManager stores "intro_<mechanic>" in
## PlayerProgress.tips_seen) and never to a player already past that level.
##
## The card plays the mechanic in miniature:
## - Portal: a block ENTERS A, comes out of the other A and CONTINUES.
## - Sequence: the FIRST MOVE launches and comes back with its next arrow,
##   the SECOND MOVE escapes.
## - Movable: an arrow HITs the Movable block, PUSHes it, it MOVES ONE CELL.
## - Magnet (76): the magnet LEAVES, the block BEHIND it slides into its place.
## Reduced motion: the same picture, still. Every visible word comes from
## TEXT, one entry per mechanic, so it can be translated in one place.

signal finished

const TEXT := {
	"portal": {"badge": "NEW MECHANIC!", "name": "PORTAL", "steps": ["ENTER A", "EXIT A", "CONTINUE"]},
	"sequence": {"badge": "NEW MECHANIC!", "name": "SEQUENCE", "steps": ["FIRST MOVE CHANGES IT", "SECOND MOVE ESCAPES"]},
	"movable": {"badge": "NEW MECHANIC!", "name": "MOVABLE", "steps": ["HIT", "PUSH", "MOVES ONE CELL"],
		"note": "BLOCKED BEHIND = CAN'T MOVE  ·  IT NEVER HAS TO LEAVE"},
	"magnet": {"badge": "NEW MECHANIC!", "name": "MAGNET", "steps": ["BLOCK BEHIND", "MAGNET LEAVES"],
		"note": "THE BLOCK BEHIND SLIDES INTO ITS PLACE  ·  NOTHING BEHIND = NOTHING MOVES"},
}
const HOLD := 1.8  # seconds before play starts by itself
const HOLD_LONG := 2.2  # a card with a note line (Movable)
const PORTAL_COLOR := Color("#00D8C4")
const BLOCK_COLOR := Color("#FF4D5E")
const SEQ_COLOR := Color("#2F8CFF")
const CRATE_FACE := Color("#C08A4B")
const CRATE_DARK := Color("#4A2C12")
const MAGNET_PINK := Color("#E0457B")

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
	_diagram.mechanic = mechanic
	_diagram.steps = t["steps"]
	_diagram.reduced = reduced
	box.add_child(_diagram)
	if t.has("note"):
		box.add_child(_label(t["note"], 19, Color(1, 1, 1, 0.78)))
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
	get_tree().create_timer(hold_seconds()).timeout.connect(close)
	match mechanic:
		"sequence": AudioManager.play_sequence()
		"movable", "magnet": AudioManager.play_push()
		_: AudioManager.play_portal()


## How long the card stays before play starts by itself.
func hold_seconds() -> float:
	return HOLD_LONG if TEXT[mechanic].has("note") else HOLD


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


## The miniature for each mechanic, and its step words underneath.
class Diagram extends Control:
	var mechanic := "portal"
	var steps: Array = []
	var reduced := false
	var t := 0.0  # 0..1 progress of the animation

	func play() -> void:
		var tw := create_tween()
		tw.tween_property(self, "t", 1.0, 1.15 if mechanic == "portal" else 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		match mechanic:
			"sequence": _draw_sequence()
			"movable": _draw_movable()
			"magnet": _draw_magnet()
			_: _draw_portal()

	func _draw_portal() -> void:
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
			_block(Vector2(w * 0.12, y), 1.0, MechanicIntro.BLOCK_COLOR, Vector2.RIGHT)
			_block(Vector2(w * 0.88, y), 1.0, MechanicIntro.BLOCK_COLOR, Vector2.RIGHT)
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
			_block(pos, clampf(sc, 0.15, 1.0), MechanicIntro.BLOCK_COLOR, Vector2.RIGHT)
		_words([w * 0.30, w * 0.70, w * 0.92], y + 76)

	## Sequence: arrow RIGHT with a small NEXT arrow UP. First move: a dash
	## to the right and back, then the arrow becomes UP. Second move: up and
	## away.
	func _draw_sequence() -> void:
		var w := size.x
		var y := 62.0
		var home := Vector2(w * 0.27, y)
		var faint := Color(1, 1, 1, 0.35)
		draw_line(home + Vector2(36, 0), Vector2(w * 0.47, y), faint, 3.0, true)
		var home2 := Vector2(w * 0.73, y)
		draw_line(home2 - Vector2(0, 36), Vector2(home2.x, 2), faint, 3.0, true)
		if reduced:
			_block(home, 1.0, MechanicIntro.SEQ_COLOR, Vector2.RIGHT, Vector2.UP)
			_block(home2, 1.0, MechanicIntro.SEQ_COLOR, Vector2.UP)
		else:
			var pos := home
			var dir := Vector2.RIGHT
			var next := Vector2.UP
			if t < 0.4:
				pos = home.lerp(home + Vector2(w * 0.16, 0), sin(t / 0.4 * PI))
			else:
				dir = Vector2.UP
				next = Vector2.ZERO
				pos = home
				if t > 0.62:
					pos = home + Vector2(0, -(t - 0.62) / 0.38 * 70.0)
			_block(pos, 1.0, MechanicIntro.SEQ_COLOR, dir, next)
			_block(home2, 0.6, Color(MechanicIntro.SEQ_COLOR, 0.35), Vector2.UP)
		_words([w * 0.27, w * 0.73], y + 66)

	## Movable: an arrow (RIGHT) hits the Movable block, which slides one
	## cell; the arrow stays where it was.
	func _draw_movable() -> void:
		var w := size.x
		var y := 52.0
		var cell := 64.0
		var arrow_home := Vector2(w * 0.22, y)
		var crate_home := Vector2(w * 0.50, y)
		# The board cells under the crate's start and target.
		for x in [crate_home.x, crate_home.x + cell]:
			var r := Rect2(Vector2(x - 28, y - 28), Vector2(56, 56))
			draw_rect(r, Color(1, 1, 1, 0.08), true)
		var arrow_pos := arrow_home
		var crate_pos := crate_home + (Vector2(cell, 0) if reduced else Vector2.ZERO)
		if not reduced:
			if t < 0.3:
				arrow_pos = arrow_home.lerp(crate_home - Vector2(cell * 0.85, 0), t / 0.3)
			elif t < 0.65:
				arrow_pos = (crate_home - Vector2(cell * 0.85, 0)).lerp(arrow_home, (t - 0.3) / 0.35)
				crate_pos = crate_home.lerp(crate_home + Vector2(cell, 0), clampf((t - 0.3) / 0.25, 0.0, 1.0))
			else:
				crate_pos = crate_home + Vector2(cell, 0)
		_block(arrow_pos, 1.0, MechanicIntro.BLOCK_COLOR, Vector2.RIGHT)
		_crate(crate_pos)
		_words([w * 0.22, w * 0.50, w * 0.80], y + 76)

	## Magnet: red (the magnet, a horseshoe on its back) flies out to the
	## right; blue, behind it on the dotted line, slides into its cell.
	func _draw_magnet() -> void:
		var w := size.x
		var y := 52.0
		var mag_home := Vector2(w * 0.62, y)
		var blue_home := Vector2(w * 0.24, y)
		for x in [blue_home.x, mag_home.x]:
			draw_rect(Rect2(Vector2(x - 28, y - 28), Vector2(56, 56)), Color(1, 1, 1, 0.08), true)
		var mag_pos := mag_home
		var blue_pos := blue_home
		var mag_gone := reduced
		if reduced:
			blue_pos = mag_home
		else:
			if t < 0.4:
				mag_pos = mag_home.lerp(Vector2(w + 40.0, y), t / 0.4)
			else:
				mag_gone = true
			if t > 0.4:
				blue_pos = blue_home.lerp(mag_home, clampf((t - 0.4) / 0.35, 0.0, 1.0))
		if not mag_gone:
			var dot := blue_pos.x + 30.0
			while dot < mag_pos.x - 30.0:
				draw_circle(Vector2(dot, y), 3.0, MechanicIntro.MAGNET_PINK)
				dot += 12.0
			_block(mag_pos, 1.0, MechanicIntro.BLOCK_COLOR, Vector2.RIGHT)
			var c := mag_pos + Vector2(-15, 0)
			draw_arc(c, 9.0, PI * 0.5, PI * 1.5, 12, Color.WHITE, 7.0, true)
			draw_arc(c, 9.0, PI * 0.5, PI * 1.5, 12, MechanicIntro.MAGNET_PINK, 4.0, true)
		_block(blue_pos, 1.0, MechanicIntro.SEQ_COLOR, Vector2.UP)
		_words([w * 0.24, w * 0.66], y + 76)

	func _words(xs: Array, y: float) -> void:
		var font := Palette.font(900)
		var w := size.x
		for i in mini(steps.size(), xs.size()):
			var txt: String = steps[i]
			var s := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
			var x: float = clampf(xs[i] - s.x * 0.5, 0.0, w - s.x)
			draw_string(font, Vector2(x, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.92))

	## A colored block with an arrow (`dir`) and, if `next` is set, the
	## small NEXT arrow on a white disc in its corner (as on the board).
	func _block(at: Vector2, sc: float, color: Color, dir: Vector2, next: Vector2 = Vector2.ZERO) -> void:
		var half := 24.0 * sc
		var r := Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0)
		var st := StyleBoxFlat.new()
		st.bg_color = color
		st.set_corner_radius_all(int(10 * sc))
		st.draw(get_canvas_item(), r)
		if sc > 0.5:
			var h := 12.0 * sc
			var side := Vector2(-dir.y, dir.x)
			draw_colored_polygon(PackedVector2Array([at + dir * h, at - dir * h * 0.4 + side * h * 0.8, at - dir * h * 0.4 - side * h * 0.8]), Color.WHITE)
		if next != Vector2.ZERO:
			var c := at + Vector2(half * 0.75, -half * 0.75)
			draw_circle(c, 11.0, Color.WHITE)
			var side2 := Vector2(-next.y, next.x)
			draw_colored_polygon(PackedVector2Array([c + next * 7.0, c - next * 4.0 + side2 * 6.0, c - next * 4.0 - side2 * 6.0]), Color("#1D1A2E"))

	## The Movable block: a wooden crate, no arrow (as on the board).
	func _crate(at: Vector2) -> void:
		var r := Rect2(at - Vector2(26, 26), Vector2(52, 52))
		draw_rect(r, MechanicIntro.CRATE_FACE, true)
		draw_rect(r.grow(-2.5), MechanicIntro.CRATE_DARK, false, 5.0)
		draw_line(r.position + Vector2(6, 46), r.position + Vector2(46, 6), MechanicIntro.CRATE_DARK, 4.0)
