class_name Shapes
## Small vector shapes drawn in code (no image assets).


static func star_points(center: Vector2, r_outer: float, r_inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + PI * i / 5.0
		pts.append(center + Vector2.from_angle(a) * (r_outer if i % 2 == 0 else r_inner))
	return pts


static func draw_star(ci: CanvasItem, center: Vector2, r: float, fill: Color, outline: Color = Color(0, 0, 0, 0)) -> void:
	var pts := star_points(center, r, r * 0.48)
	ci.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	if outline.a > 0.0:
		ci.draw_polyline(pts, outline, maxf(2.0, r * 0.12), true)
	else:
		ci.draw_polyline(pts, fill, 1.2, true)
