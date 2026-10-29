class_name GorillaArt
extends Node2D
## Temporary, resolution-independent character art. Origin is at the feet.
## `run_time` is seconds; the game owns the clock and calls queue_redraw().

var run_time: float = 0.0
var airborne: bool = false
var ducking: bool = false
var is_pursuer: bool = false
var hit_flash: float = 0.0

const INK: Color = Color("#17252b")
const FUR_DARK: Color = Color("#23343b")
const FUR: Color = Color("#35484d")
const FUR_LIGHT: Color = Color("#4a6061")
const SKIN_DARK: Color = Color("#64706a")
const SKIN: Color = Color("#94a08a")
const SKIN_LIGHT: Color = Color("#b6b995")
const SILVER: Color = Color("#a2b8b1")


func _draw() -> void:
	var stride: float = sin(run_time * 13.0)
	var bounce: float = -abs(cos(run_time * 13.0)) * 3.0
	if airborne:
		stride = 0.65
		bounce = -4.0
	if ducking and not airborne:
		_draw_crouching(stride)
	else:
		_draw_running(stride, bounce)
	if hit_flash > 0.0 and fmod(hit_flash, 0.16) > 0.08:
		_ellipse(Vector2(0.0, -65.0), Vector2(48.0, 59.0), Color(1.0, 0.82, 0.4, 0.17))


func _draw_running(stride: float, bounce: float) -> void:
	var lift: Vector2 = Vector2(0.0, bounce)
	_draw_shadow(airborne)
	# Far limbs use a darker fill to separate them from the near silhouette.
	var far_knee: Vector2 = Vector2(-21.0 + stride * 12.0, -23.0 - abs(stride) * 4.0)
	var far_foot: Vector2 = Vector2(-28.0 - stride * 15.0, -5.0 - maxf(stride, 0.0) * 14.0)
	_limb(Vector2(-19.0, -49.0) + lift, far_knee + lift, far_foot, 16.0, FUR_DARK)
	_foot(far_foot + Vector2(4.0, 0.0), FUR_DARK)
	_limb(Vector2(-27.0, -79.0) + lift, Vector2(-40.0, -47.0 + stride * 6.0), Vector2(-44.0 + stride * 13.0, -17.0 - maxf(-stride, 0.0) * 10.0), 17.0, FUR_DARK)
	_knuckles(Vector2(-44.0 + stride * 13.0, -16.0 - maxf(-stride, 0.0) * 10.0), FUR_DARK)
	# Broad rounded torso and a warm rim along the mountain-facing shoulder.
	_ellipse(Vector2(-6.0, -66.0) + lift, Vector2(38.0, 43.0), INK)
	_ellipse(Vector2(-5.0, -66.0) + lift, Vector2(34.5, 39.5), FUR)
	_ellipse(Vector2(-19.0, -72.0) + lift, Vector2(22.0, 31.0), FUR_LIGHT)
	if is_pursuer:
		_blob([Vector2(-36.0, -88.0), Vector2(-24.0, -104.0), Vector2(4.0, -98.0), Vector2(14.0, -72.0), Vector2(4.0, -47.0), Vector2(-25.0, -48.0), Vector2(-38.0, -64.0)], SILVER, false, lift)
		_ellipse(Vector2(-21.0, -77.0) + lift, Vector2(15.0, 23.0), Color("#c0cec1"))
	else:
		_arc_line(Vector2(-14.0, -74.0) + lift, Vector2(24.0, 27.0), PI * 1.0, PI * 1.5, Color("#7e9690"), 3.0)
	# Chest is a separate soft plane instead of an outlined patch.
	_ellipse(Vector2(8.0, -65.0) + lift, Vector2(20.0, 27.0), Color("#65746b"))
	_ellipse(Vector2(14.0, -70.0) + lift, Vector2(12.0, 19.0), Color("#81907c"))
	var near_knee: Vector2 = Vector2(4.0 - stride * 13.0, -24.0 - maxf(-stride, 0.0) * 6.0)
	var near_foot: Vector2 = Vector2(14.0 + stride * 19.0, -5.0 - maxf(-stride, 0.0) * 12.0)
	_limb(Vector2(-2.0, -48.0) + lift, near_knee + lift, near_foot, 17.0, FUR)
	_foot(near_foot + Vector2(4.0, 0.0), FUR)
	# Rearward head tilt and forward muzzle make the rightward direction clear.
	_draw_head(Vector2(16.0, -103.0) + lift, false)
	var elbow: Vector2 = Vector2(31.0 - stride * 4.0, -47.0 - stride * 9.0)
	var hand: Vector2 = Vector2(45.0 - stride * 15.0, -18.0 - maxf(stride, 0.0) * 16.0)
	if airborne:
		elbow = Vector2(34.0, -66.0)
		hand = Vector2(53.0, -52.0)
	_limb(Vector2(17.0, -77.0) + lift, elbow + lift, hand, 18.5, FUR)
	_ellipse(Vector2(19.0, -76.0) + lift, Vector2(15.0, 17.0), FUR_LIGHT)
	_arc_line(elbow + lift, Vector2(8.0, 8.0), -0.9, 0.65, Color("#637c78"), 2.0)
	_knuckles(hand, FUR)


func _draw_crouching(stride: float) -> void:
	_draw_shadow(false)
	var bob: Vector2 = Vector2(0.0, -abs(stride) * 1.5)
	_limb(Vector2(-28.0, -32.0), Vector2(-40.0, -18.0), Vector2(-36.0 - stride * 8.0, -5.0), 14.0, FUR_DARK)
	_foot(Vector2(-34.0 - stride * 8.0, -5.0), FUR_DARK)
	_ellipse(Vector2(-9.0, -33.0) + bob, Vector2(43.0, 28.0), INK)
	_ellipse(Vector2(-8.0, -33.0) + bob, Vector2(39.5, 24.5), FUR)
	_ellipse(Vector2(-20.0, -40.0) + bob, Vector2(24.0, 16.0), SILVER if is_pursuer else FUR_LIGHT)
	_limb(Vector2(-6.0, -26.0), Vector2(5.0, -15.0), Vector2(19.0 + stride * 9.0, -5.0), 13.0, FUR)
	_foot(Vector2(21.0 + stride * 9.0, -5.0), FUR)
	# Head is smaller in its tuck, keeping every part below a low branch.
	draw_set_transform(Vector2(28.0, -43.0) + bob, 0.0, Vector2(0.78, 0.78))
	_draw_head(Vector2.ZERO, true)
	draw_set_transform(Vector2.ZERO)
	_limb(Vector2(11.0, -35.0) + bob, Vector2(33.0, -24.0), Vector2(47.0 - stride * 7.0, -6.0), 15.0, FUR)
	_knuckles(Vector2(47.0 - stride * 7.0, -6.0), FUR)


func _draw_head(center: Vector2, tucked: bool) -> void:
	# Fur and crest, then the inset facial mask.
	_ellipse(center + Vector2(-1.0, 0.0), Vector2(29.0, 29.0), INK)
	_ellipse(center + Vector2(-1.0, 0.0), Vector2(26.0, 26.0), FUR)
	_blob([Vector2(-18.0, -17.0), Vector2(-15.0, -28.0), Vector2(-5.0, -33.0), Vector2(1.0, -28.0), Vector2(6.0, -30.0), Vector2(13.0, -20.0)], FUR, false, center)
	_ellipse(center + Vector2(-23.0, 4.0), Vector2(10.0, 13.0), INK)
	_ellipse(center + Vector2(-22.0, 4.0), Vector2(7.0, 9.0), SKIN_DARK)
	_ellipse(center + Vector2(-23.0, 4.0), Vector2(3.5, 5.0), FUR_DARK)
	_blob([Vector2(-12.0, -15.0), Vector2(2.0, -19.0), Vector2(20.0, -13.0), Vector2(24.0, 0.0), Vector2(28.0, 8.0), Vector2(22.0, 23.0), Vector2(5.0, 27.0), Vector2(-9.0, 18.0), Vector2(-14.0, 3.0)], SKIN_DARK, true, center)
	_ellipse(center + Vector2(7.0, 2.0), Vector2(18.0, 20.0), SKIN)
	_ellipse(center + Vector2(16.0, 10.0), Vector2(16.0, 13.0), SKIN_LIGHT)
	# Brows are large enough to remain readable on a small phone.
	_ellipse(center + Vector2(-2.0, -6.0), Vector2(9.0, 10.0), FUR_DARK)
	_ellipse(center + Vector2(15.0, -6.0), Vector2(8.0, 9.0), FUR_DARK)
	var pupil_shift: float = 1.5 if not tucked else 2.0
	_ellipse(center + Vector2(-0.5, -5.0), Vector2(4.8, 5.4), Color("#fff5ce"))
	_ellipse(center + Vector2(16.0, -5.0), Vector2(4.3, 5.1), Color("#fff5ce"))
	_ellipse(center + Vector2(pupil_shift, -4.0), Vector2(2.8, 3.5), INK)
	_ellipse(center + Vector2(17.0 + pupil_shift * 0.5, -4.0), Vector2(2.6, 3.3), INK)
	_ellipse(center + Vector2(pupil_shift + 0.9, -5.4), Vector2(0.9, 1.0), Color.WHITE)
	_ellipse(center + Vector2(18.4, -5.3), Vector2(0.8, 0.9), Color.WHITE)
	if is_pursuer:
		_stroke(center + Vector2(-9.0, -15.0), center + Vector2(6.0, -10.0), 6.0, FUR_DARK)
		_stroke(center + Vector2(12.0, -10.0), center + Vector2(23.0, -14.0), 6.0, FUR_DARK)
	else:
		_stroke(center + Vector2(-9.0, -15.0), center + Vector2(4.0, -16.0), 5.0, FUR_DARK)
		_stroke(center + Vector2(13.0, -15.0), center + Vector2(23.0, -13.0), 5.0, FUR_DARK)
	# Flat gorilla nose and short, upturned mouth; no monkey tail or fangs.
	_ellipse(center + Vector2(16.0, 6.0), Vector2(10.0, 6.0), SKIN_DARK)
	_ellipse(center + Vector2(13.0, 6.5), Vector2(2.3, 2.0), INK)
	_ellipse(center + Vector2(20.0, 6.0), Vector2(2.3, 2.0), INK)
	if is_pursuer:
		_stroke(center + Vector2(7.0, 18.0), center + Vector2(23.0, 15.0), 2.5, INK)
	else:
		_arc_line(center + Vector2(14.0, 11.0), Vector2(10.0, 8.0), 0.15, 2.55, INK, 2.5)
		_stroke(center + Vector2(4.0, 15.0), center + Vector2(5.0, 12.0), 2.0, INK)
	# A restrained edge highlight makes the head separate from the torso.
	_arc_line(center + Vector2(-1.0, -1.0), Vector2(25.0, 25.0), 3.55, 4.6, Color("#71847a"), 2.0)


func _draw_shadow(jumping: bool) -> void:
	var fade: float = 0.45 if jumping else 1.0
	_ellipse(Vector2(-1.0, 1.0), Vector2(55.0, 8.0), Color(0.02, 0.07, 0.07, 0.07 * fade))
	_ellipse(Vector2(-1.0, 1.0), Vector2(43.0, 5.0), Color(0.02, 0.07, 0.07, 0.12 * fade))


func _limb(shoulder: Vector2, elbow: Vector2, hand: Vector2, radius: float, color: Color) -> void:
	_stroke(shoulder, elbow, radius * 2.0 + 5.0, INK)
	_stroke(elbow, hand, radius * 1.65 + 5.0, INK)
	_stroke(shoulder, elbow, radius * 2.0, color)
	_stroke(elbow, hand, radius * 1.65, color)


func _foot(at: Vector2, color: Color) -> void:
	_ellipse(at + Vector2(3.0, 0.0), Vector2(18.0, 7.5), INK)
	_ellipse(at + Vector2(3.0, -1.5), Vector2(15.5, 5.5), color)
	for i: int in range(3):
		draw_line(at + Vector2(10.0 + float(i) * 3.0, -2.0), at + Vector2(10.0 + float(i) * 3.0, 2.0), FUR_DARK, 1.2, true)


func _knuckles(at: Vector2, color: Color) -> void:
	_ellipse(at, Vector2(17.0, 11.0), INK)
	_ellipse(at + Vector2(0.0, -1.0), Vector2(14.5, 8.5), color)
	for i: int in range(3):
		_ellipse(at + Vector2(-6.0 + float(i) * 6.0, 2.0), Vector2(3.0, 4.2), SKIN_DARK)
	_ellipse(at + Vector2(10.0, -3.0), Vector2(4.0, 5.0), FUR_LIGHT)


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	# Explicit points also work inside the crouching head's transformed drawing.
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(40):
		var a: float = TAU * float(i) / 40.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, color, 0.65, true)


func _blob(vertices: Array, color: Color, outline: bool = true, offset: Vector2 = Vector2.ZERO) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for vertex: Vector2 in vertices:
		points.append(vertex + offset)
	draw_colored_polygon(points, color)
	if outline:
		points.append(points[0])
		draw_polyline(points, INK, 2.5, true)


func _stroke(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	draw_line(from, to, color, width, true)
	draw_circle(from, width * 0.5, color, true, -1.0, true)
	draw_circle(to, width * 0.5, color, true, -1.0, true)


func _arc_line(center: Vector2, radii: Vector2, start: float, finish: float, color: Color, width: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(17):
		var a: float = lerpf(start, finish, float(i) / 16.0)
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_polyline(points, color, width, true)
