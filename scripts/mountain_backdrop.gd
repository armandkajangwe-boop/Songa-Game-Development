class_name MountainBackdrop
extends Node2D
## Illustrated, texture-free portrait scenery inspired by Rwanda's Virunga range.
## Positions use a 540 × 960 canvas; the trail surface is at y = 740.

var scroll_distance: float = 0.0
var animation_time: float = 0.0
var menu_mode: bool = false

const W: float = 540.0
const H: float = 960.0
const GROUND: float = 740.0


func _draw() -> void:
	_draw_sky()
	_draw_mountains()
	_draw_forest()
	_draw_trail()
	_draw_foreground()


func _draw_sky() -> void:
	var top := Color("d9e8d6")
	var horizon := Color("f3e9bf")
	for i in range(65):
		var t: float = float(i) / 64.0
		draw_rect(Rect2(0.0, float(i) * 10.0, W, 11.0), top.lerp(horizon, t))
	# A soft morning sun and a few quiet clouds leave room for the HUD.
	for i in range(6, 0, -1):
		draw_circle(Vector2(441.0, 192.0), 28.0 + float(i) * 10.0,
			Color(1.0, 0.95, 0.71, 0.012 * float(7 - i)))
	draw_circle(Vector2(441.0, 192.0), 27.0, Color("fff1bf"), true, -1.0, true)
	_cloud(Vector2(66.0, 158.0), 0.9, Color(0.99, 0.99, 0.88, 0.39))
	_cloud(Vector2(355.0, 122.0), 0.6, Color(0.99, 0.99, 0.89, 0.24))
	_cloud(Vector2(478.0, 312.0), 0.83, Color(0.99, 0.99, 0.88, 0.28))


func _cloud(center: Vector2, size: float, tint: Color) -> void:
	var sway: float = sin(animation_time * 0.07 + center.x) * 8.0
	_ellipse(center + Vector2(sway, 0.0), Vector2(56.0, 8.0) * size, tint)
	_ellipse(center + Vector2(17.0 + sway, -7.0) * size, Vector2(28.0, 11.0) * size, tint)
	_ellipse(center + Vector2(-21.0 + sway, -3.0) * size, Vector2(23.0, 9.0) * size, tint)


func _draw_mountains() -> void:
	var far_shift: float = fposmod(scroll_distance * 0.012, 800.0)
	for repeat_index in range(-1, 2):
		var offset: float = float(repeat_index) * 800.0 - far_shift
		_mountain(46.0 + offset, 497.0, 370.0, 226.0, Color("a7c5b7"), Color("bdd0ba"), 1.7)
		_mountain(525.0 + offset, 511.0, 285.0, 221.0, Color("9cbcaf"), Color("b0c8b3"), 3.4)
	var mid_shift: float = fposmod(scroll_distance * 0.025, 860.0)
	for repeat_index in range(-1, 2):
		var offset: float = float(repeat_index) * 860.0 - mid_shift
		_mountain(295.0 + offset, 561.0, 430.0, 339.0, Color("719b8d"), Color("94b29b"), 2.3)
		_mountain(703.0 + offset, 565.0, 324.0, 266.0, Color("80a493"), Color("9eb99e"), 4.0)
	# Strata of low cloud drift through the valleys rather than covering the peaks.
	_mist(435.0, 36.0, Color(0.88, 0.92, 0.79, 0.34), 0.5)
	_mist(491.0, 49.0, Color(0.9, 0.92, 0.78, 0.43), 1.9)
	var near_shift: float = fposmod(scroll_distance * 0.06, 660.0)
	for repeat_index in range(-1, 2):
		var offset: float = float(repeat_index) * 660.0 - near_shift
		_hill(offset - 80.0, 613.0, 490.0, 112.0, Color("5d8b73"), 0.4)
		_hill(offset + 310.0, 622.0, 390.0, 95.0, Color("537f69"), 1.2)
	_mist(565.0, 29.0, Color(0.82, 0.89, 0.73, 0.25), 2.7)


func _mountain(center_x: float, base_y: float, width: float, height: float,
		base: Color, light: Color, phase: float) -> void:
	if center_x + width * 0.5 < -30.0 or center_x - width * 0.5 > W + 30.0:
		return
	var ridge := PackedVector2Array()
	ridge.append(Vector2(center_x - width * 0.5, base_y))
	for i in range(49):
		var t: float = float(i) / 48.0
		var crown: float = pow(maxf(0.0, 1.0 - absf(t * 2.0 - 1.0)), 0.77)
		var unevenness: float = sin(t * 18.0 + phase) * 3.4 + sin(t * 39.0 + phase) * 1.7
		ridge.append(Vector2(center_x + (t - 0.5) * width,
			base_y - crown * height + unevenness * crown))
	ridge.append(Vector2(center_x + width * 0.5, base_y))
	draw_colored_polygon(ridge, base)
	# Light catches one shoulder of the cone; folds give the slopes their depth.
	var shoulder := PackedVector2Array([
		Vector2(center_x, base_y - height),
		Vector2(center_x - width * 0.08, base_y - height * 0.63),
		Vector2(center_x - width * 0.045, base_y - height * 0.39),
		Vector2(center_x - width * 0.21, base_y - height * 0.13),
		Vector2(center_x - width * 0.49, base_y),
		Vector2(center_x - width * 0.35, base_y - height * 0.34),
		Vector2(center_x - width * 0.19, base_y - height * 0.67)
	])
	draw_colored_polygon(shoulder, light)
	var shade := base.darkened(0.13)
	shade.a = 0.55
	for j in range(3):
		var p: float = float(j)
		var fold := PackedVector2Array([
			Vector2(center_x + width * (0.025 + p * 0.065), base_y - height * (0.89 - p * 0.13)),
			Vector2(center_x + width * (0.22 + p * 0.08), base_y),
			Vector2(center_x + width * (0.1 + p * 0.055), base_y - height * 0.06)
		])
		draw_colored_polygon(fold, shade)


func _hill(left: float, base_y: float, width: float, height: float, tint: Color, phase: float) -> void:
	var points := PackedVector2Array([Vector2(left, base_y + 50.0)])
	for i in range(33):
		var t: float = float(i) / 32.0
		points.append(Vector2(left + t * width,
			base_y - sin(t * PI) * height + sin(t * 13.0 + phase) * 8.0))
	points.append(Vector2(left + width, base_y + 50.0))
	draw_colored_polygon(points, tint)


func _mist(y: float, thickness: float, tint: Color, phase: float) -> void:
	var points := PackedVector2Array()
	for i in range(20):
		var x: float = float(i) * 30.0 - 15.0
		points.append(Vector2(x, y + sin(x * 0.008 + phase + animation_time * 0.04) * 9.0))
	for i in range(19, -1, -1):
		var x: float = float(i) * 30.0 - 15.0
		points.append(Vector2(x, y + thickness + sin(x * 0.011 + phase) * 7.0))
	draw_colored_polygon(points, tint)


func _draw_forest() -> void:
	# Two ranks of bamboo and forest crowns supply the middle parallax layers.
	draw_rect(Rect2(0.0, 624.0, W, 120.0), Color("35654e"))
	for i in range(-2, 20):
		var fi: float = float(i)
		var x: float = fi * 47.0 - fposmod(scroll_distance * 0.16, 47.0)
		var high: float = 568.0 + sin(fi * 2.31) * 27.0
		var tint: Color = Color("3e7359").lerp(Color("4e8060"), (sin(fi * 1.73) + 1.0) * 0.5)
		_ellipse(Vector2(x, high + 37.0), Vector2(37.0, 58.0), tint)
		_ellipse(Vector2(x + 20.0, high + 61.0), Vector2(31.0, 42.0), tint)
	for i in range(-2, 14):
		var fi: float = float(i)
		var x: float = fi * 63.0 - fposmod(scroll_distance * 0.25, 63.0)
		var base_y: float = 724.0 + sin(fi) * 7.0
		_bamboo(Vector2(x, base_y), 139.0 + sin(fi * 1.71) * 43.0,
			0.72, Color("295d46"), fi * 0.3)
	# Deep foliage directly behind the running trail.
	draw_rect(Rect2(0.0, 701.0, W, 42.0), Color("234e3b"))
	for i in range(-1, 18):
		var fi: float = float(i)
		var x: float = fi * 36.0 - fposmod(scroll_distance * 0.38, 36.0)
		_ellipse(Vector2(x, 706.0 + sin(fi * 2.0) * 5.0), Vector2(26.0, 17.0), Color("28573e"))
		if i % 3 == 0:
			_fern(Vector2(x, 735.0), 31.0, Color("46724a"), -0.2)
	# Tall edge bamboo frames the portrait without obscuring the player lane.
	_bamboo(Vector2(-12.0, 742.0), 340.0, 1.0, Color("254d36"), -0.12)
	_bamboo(Vector2(546.0, 741.0), 410.0, 1.07, Color("254d36"), 0.18)
	_bamboo(Vector2(528.0, 739.0), 313.0, 0.78, Color("376445"), 0.15)


func _bamboo(base: Vector2, height: float, size: float, tint: Color, lean: float) -> void:
	var top: Vector2 = base + Vector2(lean * height * 0.16, -height)
	draw_line(base, top, tint.darkened(0.14), 5.5 * size, true)
	draw_line(base + Vector2(1.0, 0.0), top + Vector2(1.0, 0.0), tint.lightened(0.15), 1.6 * size, true)
	for i in range(1, 7):
		var t: float = float(i) / 7.0
		var stem: Vector2 = base.lerp(top, t)
		draw_line(stem + Vector2(-3.0, 0.0) * size, stem + Vector2(3.0, 0.0) * size,
			tint.lightened(0.22), 1.4, true)
		var sign_x: float = -1.0 if i % 2 == 0 else 1.0
		var end: Vector2 = stem + Vector2(sign_x * 35.0, -20.0) * size
		draw_line(stem, end, tint, 1.5 * size, true)
		for j in range(3):
			var point: Vector2 = stem.lerp(end, 0.4 + float(j) * 0.22)
			var leaf_end: Vector2 = point + Vector2(sign_x * (16.0 + float(j) * 2.0), -9.0 + float(j) * 6.0) * size
			_leaf(point, leaf_end, 4.0 * size, tint)
			_leaf(point, point + Vector2(sign_x * 9.0, 16.0) * size, 3.5 * size, tint)


func _draw_trail() -> void:
	# A generous earthen band makes foreground controls legible.
	draw_rect(Rect2(0.0, GROUND, W, H - GROUND), Color("8b8051"))
	draw_rect(Rect2(0.0, GROUND + 12.0, W, 28.0), Color("aa9460"))
	draw_rect(Rect2(0.0, GROUND + 40.0, W, H - GROUND - 40.0), Color("8a794c"))
	var earth_top := PackedVector2Array([Vector2(0.0, 802.0)])
	for i in range(19):
		var x: float = float(i) * 30.0
		earth_top.append(Vector2(x, 805.0 + sin(x * 0.035) * 8.0 + sin(x * 0.077) * 3.0))
	earth_top.append(Vector2(W, H))
	earth_top.append(Vector2(0.0, H))
	draw_colored_polygon(earth_top, Color("716c46"))
	# Mossy rim, sunlit dust, and embedded volcanic stones.
	draw_rect(Rect2(0.0, GROUND - 2.0, W, 7.0), Color("96a965"))
	draw_line(Vector2(0.0, GROUND + 6.0), Vector2(W, GROUND + 6.0), Color("c5bc7d"), 3.0)
	for i in range(-2, 26):
		var fi: float = float(i)
		var x: float = fi * 31.0 - fposmod(scroll_distance, 31.0)
		var y: float = GROUND + 16.0 + fposmod(fi * 21.0, 56.0)
		var radius: float = 2.0 + fposmod(fi * 7.0, 4.0)
		_ellipse(Vector2(x, y), Vector2(radius * 1.6, radius * 0.7), Color("6b704e"))
		if i % 2 == 0:
			draw_line(Vector2(x - 3.0, GROUND - 1.0), Vector2(x - 6.0, GROUND - 9.0), Color("82955a"), 1.5, true)
			draw_line(Vector2(x - 3.0, GROUND - 1.0), Vector2(x + 1.0, GROUND - 6.0), Color("82955a"), 1.5, true)
	# Subtle root veins appear beneath the surface, safely below gameplay.
	for i in range(6):
		var x: float = float(i) * 118.0 - fposmod(scroll_distance * 0.7, 118.0)
		var root := PackedVector2Array([Vector2(x, 783.0), Vector2(x + 8.0, 806.0),
			Vector2(x - 5.0, 821.0), Vector2(x + 5.0, 850.0)])
		draw_polyline(root, Color(0.31, 0.34, 0.22, 0.3), 2.0, true)


func _draw_foreground() -> void:
	# Static corner ferns act as a frame; the center stays open for touch controls.
	_fern(Vector2(-7.0, 936.0), 94.0, Color("294e37"), 0.22)
	_fern(Vector2(548.0, 950.0), 112.0, Color("24472f"), -0.18)
	_fern(Vector2(526.0, 960.0), 59.0, Color("4b7044"), -0.5)


func _fern(base: Vector2, length: float, tint: Color, lean: float) -> void:
	for stalk_index in range(5):
		var angle: float = -PI * 0.82 + float(stalk_index) * PI * 0.16 + lean
		var direction := Vector2(cos(angle), sin(angle))
		var tip: Vector2 = base + direction * length * (0.8 + 0.2 * sin(float(stalk_index)))
		draw_line(base, tip, tint.lightened(0.12), 1.6, true)
		var normal := Vector2(-direction.y, direction.x)
		for i in range(1, 8):
			var t: float = float(i) / 8.0
			var center: Vector2 = base.lerp(tip, t)
			var spread: float = sin(t * PI) * length * 0.21
			_leaf(center, center + normal * spread + direction * length * 0.09, length * 0.028, tint)
			_leaf(center, center - normal * spread + direction * length * 0.09, length * 0.028, tint)


func _leaf(start: Vector2, end: Vector2, width: float, tint: Color) -> void:
	var normal := (end - start).normalized().orthogonal() * width
	var center: Vector2 = start.lerp(end, 0.43)
	draw_colored_polygon(PackedVector2Array([start, center + normal, end, center - normal * 0.7]), tint)


func _ellipse(center: Vector2, radius: Vector2, tint: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a: float = float(i) * TAU / 24.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(points, tint)
