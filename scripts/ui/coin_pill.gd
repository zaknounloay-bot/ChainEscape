class_name CoinPill
extends Button
## Coin balance, unobtrusive in the top-right corner. Tap = open the Shop.
## Counts up/down smoothly when the balance changes.

var coins: int = 0
var _shown: float = 0.0
var _tween: Tween


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	custom_minimum_size = Vector2(150, 56)


func set_coins(value: int, animate: bool = true) -> void:
	coins = value
	if _tween:
		_tween.kill()
	if not animate:
		_shown = value
		queue_redraw()
		return
	_tween = create_tween()
	_tween.tween_method(func(v): _shown = v; queue_redraw(), _shown, float(value), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pivot_offset = size * 0.5
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2(1.12, 1.12), 0.1)
	pop.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)


func _draw() -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1, 1, 1, 0.92)
	st.set_corner_radius_all(28)
	st.anti_aliasing = true
	st.shadow_color = Palette.SHADOW
	st.shadow_size = 6
	st.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	PillButton.draw_coin(self, Vector2(28, size.y * 0.5), 15.0)
	var font := Palette.font(900)
	draw_string(font, Vector2(52, size.y * 0.5 + 10), str(int(round(_shown))), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Palette.TEXT)
	# Small "+" hints that tapping opens the shop.
	draw_circle(Vector2(size.x - 20, size.y * 0.5), 11, Palette.ACCENT)
	draw_line(Vector2(size.x - 26, size.y * 0.5), Vector2(size.x - 14, size.y * 0.5), Color.WHITE, 3)
	draw_line(Vector2(size.x - 20, size.y * 0.5 - 6), Vector2(size.x - 20, size.y * 0.5 + 6), Color.WHITE, 3)
