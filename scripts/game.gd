extends Node2D
## Scene composition, touch controls, presentation and local preferences.

const Model = preload("res://scripts/runner_model.gd")
const Backdrop = preload("res://scripts/mountain_backdrop.gd")
const Gorilla = preload("res://scripts/gorilla_art.gd")
const Sounds = preload("res://scripts/soundscape.gd")
const BODY = preload("res://assets/fonts/OpenSans-Regular.ttf")
const BOLD = preload("res://assets/fonts/OpenSans-ExtraBold.ttf")
const INK := Color("183e33")
const CREAM := Color("fff7df")
const GOLD := Color("f5ca62")
const MUTED := Color("718575")
const SAVE_PATH := "user://songa.cfg"

var model = Model.new()
var backdrop = Backdrop.new()
var hero = Gorilla.new()
var pursuer = Gorilla.new()
var sound = Sounds.new()
var hud: Control
var title_screen: Control
var run_screen: Control
var pause_screen: Control
var end_screen: Control
var distance_label: Label
var banana_label: Label
var lives_label: Label
var hint_label: Label
var result_distance: Label
var result_bananas: Label
var result_best: Label
var menu_best: Label
var sound_button: Button
var chase_fill: ColorRect
var jump_button: Button
var slide_button: Button
var _clock := 0.0
var _scroll := 0.0
var _slide_left := 0.0
var _slide_pressed := false
var _key_duck := false
var _pointer_id := -99
var _pointer_start := Vector2.ZERO
var _did_swipe := false
var _particles: Array[Dictionary] = []
var _last_phase: int = -1
var _seen_bananas := 0
var _seen_lives := 3


func _ready() -> void:
	backdrop.z_index = -10
	add_child(backdrop)
	pursuer.is_pursuer = true
	add_child(pursuer)
	add_child(hero)
	add_child(sound)
	_load_progress()
	_build_interface()
	_sync_screens()
	_update_characters()
	if "--demo" in OS.get_cmdline_user_args():
		_start_run()
		# Only for repeatable screenshots; the ordinary game uses fresh courses.
		model.begin(2026)
		model.tick(1.4)


func _physics_process(delta: float) -> void:
	if model.phase == Model.Phase.RUNNING:
		_slide_left = maxf(0.0, _slide_left - delta)
		model.set_ducking(_slide_pressed or _key_duck or _slide_left > 0.0)
		var before_distance: float = model.distance
		model.tick(delta)
		_scroll += (model.distance - before_distance) * 20.0
		if model.bananas > _seen_bananas:
			sound.play_pickup()
			_burst(Vector2(model.player_x + 20, model.player_y - 62), GOLD, 9)
		if model.lives < _seen_lives:
			sound.play_hit()
			_burst(Vector2(model.player_x, model.player_y - 38), CREAM, 12)
		_seen_bananas = model.bananas
		_seen_lives = model.lives
	if _last_phase != model.phase:
		if model.phase == Model.Phase.GAME_OVER:
			sound.play_end()
			_save_progress()
		_sync_screens()


func _process(delta: float) -> void:
	if model.phase == Model.Phase.RUNNING or model.phase == Model.Phase.TITLE:
		_clock += minf(delta, 0.1)
		if model.phase == Model.Phase.TITLE:
			_scroll += delta * 26.0
		for particle in _particles:
			particle["life"] -= delta
			particle["position"] += particle["velocity"] * delta
			particle["velocity"].y += delta * 160.0
		_particles = _particles.filter(func(p: Dictionary) -> bool: return p["life"] > 0)
	backdrop.scroll_distance = _scroll
	backdrop.animation_time = _clock
	backdrop.queue_redraw()
	_update_characters()
	_update_hud()
	queue_redraw()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST] and is_instance_valid(hud):
		_save_progress()
		if model.phase == Model.Phase.RUNNING:
			_toggle_pause()


func _input(event: InputEvent) -> void:
	# Claim shortcuts before GUI focus sees Space as ui_accept. Otherwise a jump
	# can also activate whichever menu or pause button was last clicked.
	if event is InputEventKey and event.keycode in [KEY_ESCAPE, KEY_P, KEY_SPACE, KEY_UP, KEY_W, KEY_DOWN, KEY_S, KEY_SHIFT]:
		get_viewport().set_input_as_handled()
		if event.echo:
			return
		if event.keycode in [KEY_ESCAPE, KEY_P] and event.pressed:
			_toggle_pause()
		elif event.keycode in [KEY_SPACE, KEY_UP, KEY_W] and event.pressed:
			if model.phase == Model.Phase.TITLE or model.phase == Model.Phase.GAME_OVER:
				_start_run()
			else:
				_jump()
		elif event.keycode in [KEY_DOWN, KEY_S, KEY_SHIFT]:
			_key_duck = event.pressed


func _unhandled_input(event: InputEvent) -> void:
	if model.phase != Model.Phase.RUNNING:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_pointer_begin(event.position, event.index)
		else:
			_pointer_end(event.position, event.index)
	elif event is InputEventScreenDrag:
		_pointer_move(event.position, event.index)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pointer_begin(event.position, -1)
			else:
				_pointer_end(event.position, -1)
	elif event is InputEventMouseMotion and _pointer_id == -1:
		_pointer_move(event.position, -1)


func _pointer_begin(at: Vector2, pointer: int) -> void:
	if _pointer_id != -99:
		return
	_pointer_id = pointer
	_pointer_start = at
	_did_swipe = false


func _pointer_move(at: Vector2, pointer: int) -> void:
	if pointer != _pointer_id or _did_swipe:
		return
	if at.y - _pointer_start.y > 44.0:
		_slide_left = 0.85
		_did_swipe = true


func _pointer_end(at: Vector2, pointer: int) -> void:
	if pointer != _pointer_id:
		return
	_pointer_move(at, pointer)
	if not _did_swipe:
		_jump()
	_pointer_id = -99


func _jump() -> void:
	var could_jump: bool = model.phase == Model.Phase.RUNNING and model.is_grounded()
	_slide_left = 0.0
	model.jump()
	if could_jump:
		sound.play_jump()
		_burst(Vector2(model.player_x, model.ground_y - 2), Color("bbbe8b"), 5)


func _clear_inputs() -> void:
	_slide_left = 0.0
	_slide_pressed = false
	_key_duck = false
	_pointer_id = -99
	model.set_ducking(false)


func _start_run() -> void:
	_clear_inputs()
	model.begin(randi() & 0x7fffffff)
	_scroll = 0.0
	_seen_bananas = 0
	_seen_lives = 3
	_particles.clear()
	sound.play_start()
	_sync_screens()


func _toggle_pause() -> void:
	if model.phase == Model.Phase.RUNNING:
		_save_progress()
	_clear_inputs()
	model.toggle_pause()
	_sync_screens()


func _go_home() -> void:
	_save_progress()
	_clear_inputs()
	model.reset_to_title()
	_particles.clear()
	_sync_screens()


func _toggle_sound() -> void:
	sound.enabled = not sound.enabled
	sound_button.text = "SOUND ON" if sound.enabled else "SOUND OFF"
	_save_progress()


func _update_characters() -> void:
	var is_title: bool = model.phase == Model.Phase.TITLE
	hero.position = Vector2(324, 730) if is_title else Vector2(model.player_x, model.player_y)
	hero.scale = Vector2.ONE * (1.30 if is_title else 0.84)
	if model.ducking and not is_title:
		hero.scale.y = 0.64
	hero.run_time = _clock
	hero.airborne = not model.is_grounded() and not is_title
	hero.ducking = model.ducking and not is_title
	hero.hit_flash = model.hit_flash
	hero.modulate.a = 0.55 if model.invulnerability > 0 and fmod(_clock, 0.16) < 0.08 else 1.0
	hero.queue_redraw()
	pursuer.position = Vector2(99, 731) if is_title else Vector2(25 + model.chase_pressure * 63, 740)
	pursuer.scale = Vector2.ONE * (1.51 if is_title else 1.14)
	pursuer.run_time = _clock + 0.3
	pursuer.queue_redraw()


func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = _screen(layer)
	title_screen = _screen(hud)
	run_screen = _screen(hud)
	pause_screen = _screen(hud)
	end_screen = _screen(hud)
	_build_title()
	_build_run_hud()
	_build_pause()
	_build_end()


func _build_title() -> void:
	_label(title_screen, "A RWANDAN ADVENTURE", Rect2(34, 49, 325, 24), 12, INK, true)
	sound_button = _button(title_screen, "SOUND ON", Rect2(385, 43, 123, 38), _toggle_sound, false)
	sound_button.add_theme_font_size_override("font_size", 11)
	sound_button.text = "SOUND ON" if sound.enabled else "SOUND OFF"
	# A drop-in path for the approved transparent brand asset. Until then use type.
	if ResourceLoader.exists("res://assets/branding/songa_logo.png"):
		var logo := TextureRect.new()
		logo.texture = load("res://assets/branding/songa_logo.png")
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.position = Vector2(20, 113)
		logo.size = Vector2(500, 191)
		title_screen.add_child(logo)
	else:
		_label(title_screen, "SONGA", Rect2(28, 116, 484, 122), 91, Color("654222"), true)
		_label(title_screen, "SONGA", Rect2(28, 110, 484, 122), 91, Color("e5af42"), true)
		_label(title_screen, "RISE OF THE SILVERBACK", Rect2(36, 237, 470, 27), 17, INK, true)
	_panel(title_screen, Rect2(36, 281, 45, 3), GOLD, 1)
	_label(title_screen, "Small gorilla. Big adventure.", Rect2(36, 301, 480, 31), 20, INK)
	_label(title_screen, "KINIGI · MUSANZE · RWANDA", Rect2(36, 347, 480, 24), 11, Color("486b58"), true)
	_panel(title_screen, Rect2(20, 764, 500, 175), Color(0.98, 0.96, 0.87, 0.95), 23)
	_label(title_screen, "VOLCANOES NATIONAL PARK", Rect2(30, 781, 480, 22), 12, INK, true, HORIZONTAL_ALIGNMENT_CENTER)
	_label(title_screen, "Tap to jump · Swipe down to slide", Rect2(30, 808, 480, 24), 14, Color("5c7460"), false, HORIZONTAL_ALIGNMENT_CENTER)
	_button(title_screen, "LET’S RUN  →", Rect2(40, 850, 460, 62), _start_run)
	menu_best = _label(title_screen, "", Rect2(30, 939, 480, 19), 10, CREAM, false, HORIZONTAL_ALIGNMENT_CENTER)


func _build_run_hud() -> void:
	_panel(run_screen, Rect2(20, 43, 500, 98), Color(1.0, 0.98, 0.90, 0.95), 22)
	_label(run_screen, "DISTANCE", Rect2(39, 56, 145, 20), 10, MUTED, true)
	distance_label = _label(run_screen, "0 m", Rect2(37, 78, 181, 45), 31, INK, true)
	_label(run_screen, "BANANAS", Rect2(235, 56, 150, 20), 10, MUTED, true)
	banana_label = _label(run_screen, "0", Rect2(235, 81, 100, 39), 27, INK, true)
	lives_label = _label(run_screen, "♥ ♥ ♥", Rect2(319, 83, 118, 27), 19, Color("b57743"), true)
	_button(run_screen, "Ⅱ", Rect2(449, 67, 50, 50), _toggle_pause, false)
	_label(run_screen, "THE CHASE IS ON", Rect2(31, 160, 206, 20), 10, INK, true)
	_panel(run_screen, Rect2(31, 189, 130, 5), Color(0.12, 0.26, 0.2, 0.13), 2)
	chase_fill = ColorRect.new()
	chase_fill.position = Vector2(31, 189)
	chase_fill.size = Vector2(26, 5)
	chase_fill.color = Color("c38b45")
	chase_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	run_screen.add_child(chase_fill)
	hint_label = _label(run_screen, "", Rect2(26, 225, 488, 30), 16, INK, true, HORIZONTAL_ALIGNMENT_CENTER)
	_panel(run_screen, Rect2(20, 811, 500, 124), Color(0.97, 0.96, 0.86, 0.94), 23)
	slide_button = _button(run_screen, "↓  SLIDE", Rect2(35, 829, 190, 65), func(): pass, false)
	slide_button.button_down.connect(func(): _slide_pressed = true)
	slide_button.button_up.connect(func(): _slide_pressed = false)
	jump_button = _button(run_screen, "↑  JUMP", Rect2(240, 829, 265, 65), func(): pass)
	jump_button.button_down.connect(_jump)
	_label(run_screen, "Tap anywhere to jump · Swipe down to slide", Rect2(30, 905, 480, 21), 11, INK, false, HORIZONTAL_ALIGNMENT_CENTER)


func _build_pause() -> void:
	_scrim(pause_screen)
	_panel(pause_screen, Rect2(30, 290, 480, 367), CREAM, 28)
	_label(pause_screen, "A MOMENT IN THE MIST", Rect2(60, 320, 420, 25), 10, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER)
	_label(pause_screen, "Take a breath.", Rect2(50, 365, 440, 55), 32, INK, true, HORIZONTAL_ALIGNMENT_CENTER)
	_label(pause_screen, "The forest can wait.", Rect2(50, 427, 440, 30), 17, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	_button(pause_screen, "KEEP RUNNING  →", Rect2(57, 490, 426, 64), _toggle_pause)
	_button(pause_screen, "BACK TO CAMP", Rect2(57, 572, 426, 53), _go_home, false)


func _build_end() -> void:
	_scrim(end_screen)
	_panel(end_screen, Rect2(25, 232, 490, 484), CREAM, 28)
	_label(end_screen, "CAUGHT UP — TRY AGAIN", Rect2(50, 260, 440, 24), 10, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER)
	_label(end_screen, "A little breather!", Rect2(40, 300, 460, 58), 32, INK, true, HORIZONTAL_ALIGNMENT_CENTER)
	_label(end_screen, "Every great adventure takes practice.", Rect2(30, 369, 480, 28), 15, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	_label(end_screen, "DISTANCE", Rect2(65, 427, 180, 20), 11, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER)
	_label(end_screen, "BANANAS", Rect2(295, 427, 180, 20), 11, MUTED, true, HORIZONTAL_ALIGNMENT_CENTER)
	result_distance = _label(end_screen, "", Rect2(50, 454, 210, 52), 31, INK, true, HORIZONTAL_ALIGNMENT_CENTER)
	result_bananas = _label(end_screen, "", Rect2(280, 454, 210, 52), 31, INK, true, HORIZONTAL_ALIGNMENT_CENTER)
	result_best = _label(end_screen, "", Rect2(40, 517, 460, 25), 12, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	_button(end_screen, "RUN AGAIN  →", Rect2(50, 565, 440, 66), _start_run)
	_button(end_screen, "BACK TO CAMP", Rect2(50, 648, 440, 43), _go_home, false)


func _sync_screens() -> void:
	if not is_instance_valid(title_screen):
		return
	_last_phase = model.phase
	title_screen.visible = model.phase == Model.Phase.TITLE
	run_screen.visible = model.phase != Model.Phase.TITLE
	pause_screen.visible = model.phase == Model.Phase.PAUSED
	end_screen.visible = model.phase == Model.Phase.GAME_OVER
	slide_button.disabled = model.phase != Model.Phase.RUNNING
	jump_button.disabled = model.phase != Model.Phase.RUNNING
	result_distance.text = "%d m" % int(model.distance)
	result_bananas.text = str(model.bananas)
	result_best.text = "PERSONAL BEST  ·  %d m" % int(model.best_distance)
	menu_best.text = "PERSONAL BEST  %d m   ·   PLAYABLE PROTOTYPE" % int(model.best_distance)
	_update_hud()


func _update_hud() -> void:
	if not is_instance_valid(distance_label):
		return
	distance_label.text = "%d m" % int(model.distance)
	banana_label.text = str(model.bananas)
	lives_label.text = "♥ ".repeat(model.lives) + "♡ ".repeat(3 - model.lives)
	chase_fill.size.x = 130.0 * model.chase_pressure
	if model.elapsed < 3.0:
		hint_label.text = "Let’s go, Songa! Tap to jump."
	elif model.elapsed < 6.0:
		hint_label.text = "Jump over rocks and fallen logs."
	elif model.elapsed < 10.0:
		hint_label.text = "Swipe down under low branches."
	else:
		hint_label.text = ""


func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		var best: float = float(config.get_value("progress", "best_distance", 0.0))
		model.best_distance = maxf(0, best) if is_finite(best) else 0.0
		sound.enabled = bool(config.get_value("preferences", "sound", true))


func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "best_distance", model.best_distance)
	config.set_value("preferences", "sound", sound.enabled)
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Local progress could not be saved (%s)." % error_string(error))


func _screen(parent: Node) -> Control:
	var control := Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(control)
	return control


func _label(parent: Node, text: String, rect: Rect2, size_px: int, color: Color, bold := false, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", BOLD if bold else BODY)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _style(color: Color, radius: int, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1 if border.a > 0 else 0)
	style.border_color = border
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style


func _panel(parent: Node, rect: Rect2, color: Color, radius: int) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(color, radius))
	parent.add_child(panel)
	return panel


func _button(parent: Node, text: String, rect: Rect2, action: Callable, primary := true) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_override("font", BOLD)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	var base := GOLD if primary else Color("e4e7ce")
	button.add_theme_stylebox_override("normal", _style(base, 16))
	button.add_theme_stylebox_override("hover", _style(base.lightened(0.09), 16))
	button.add_theme_stylebox_override("pressed", _style(base.darkened(0.10), 16))
	button.add_theme_stylebox_override("disabled", _style(base.darkened(0.10), 16))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 16, INK))
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _scrim(parent: Node) -> void:
	var scrim := ColorRect.new()
	scrim.position = Vector2.ZERO
	scrim.size = Vector2(540, 960)
	scrim.color = Color(0.04, 0.13, 0.10, 0.76)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(scrim)


func _burst(at: Vector2, color: Color, amount: int) -> void:
	for i in range(amount):
		var direction := Vector2.from_angle(-PI + i * PI / amount)
		_particles.append({"position": at, "velocity": direction * (55.0 + i * 8.0), "life": 0.48, "color": color})


func _draw() -> void:
	if model.phase != Model.Phase.TITLE:
		for obstacle in model.obstacles:
			_draw_obstacle(obstacle)
		for pickup in model.pickups:
			_draw_banana(Vector2(float(pickup["x"]), float(pickup["y"])))
	for particle in _particles:
		var color: Color = particle["color"]
		color.a = clampf(float(particle["life"]) / 0.48, 0, 1)
		draw_circle(particle["position"], 2.8, color, true, -1.0, true)


func _draw_banana(at: Vector2) -> void:
	var bob := sin(_clock * 4.0 + at.x * 0.02) * 2.0
	var center := at + Vector2(0, bob - 3)
	draw_circle(center, 17, Color(0.98, 0.83, 0.38, 0.11), true, -1, true)
	draw_arc(center + Vector2(0, -6), 12, 0.2, 2.7, 14, Color("765628"), 7, true)
	draw_arc(center + Vector2(0, -6), 12, 0.2, 2.7, 14, GOLD, 5, true)
	draw_arc(center + Vector2(0, -8), 10, 0.5, 2.5, 12, Color("fff0a9"), 1.7, true)


func _draw_obstacle(obstacle: Dictionary) -> void:
	var x := float(obstacle["x"])
	var y := float(obstacle["y"])
	var width := float(obstacle["width"])
	var height := float(obstacle["height"])
	var kind := str(obstacle["kind"])
	if kind == "branch":
		# A suspended bamboo bough leaves a generous passage underneath.
		draw_line(Vector2(x - 8, y + 14), Vector2(x + width + 16, y + 28), Color("304b35"), 13, true)
		draw_line(Vector2(x - 8, y + 10), Vector2(x + width + 16, y + 24), Color("79945a"), 6, true)
		for i in range(6):
			var anchor := Vector2(x + i * width / 5, y + 20)
			var end := anchor + Vector2(sin(i * 3.0) * 12, height - 24)
			draw_line(anchor, end, Color("45623d"), 3, true)
			for j in range(3):
				var p := anchor.lerp(end, 0.3 + j * 0.24)
				var side := -1.0 if (i + j) % 2 == 0 else 1.0
				draw_colored_polygon(PackedVector2Array([p, p + Vector2(side * 19, -12), p + Vector2(side * 16, 9), p + Vector2(0, 12)]), Color("658148") if i % 2 else Color("385b3c"))
		_hint("SLIDE ↓", Vector2(x + width * 0.5, y - 18))
	elif kind == "log":
		var rect := Rect2(x, y + 4, width, height - 4)
		draw_style_box(_style(Color("433a2b"), 12), Rect2(x - 2, y + 2, width + 4, height + 1))
		draw_style_box(_style(Color("95643b"), 10), rect)
		for i in range(3):
			draw_line(Vector2(x + 6, y + 11 + i * 8), Vector2(x + width - 10, y + 8 + i * 9), Color("5e442d"), 2, true)
		draw_circle(Vector2(x + width - 9, y + height * 0.5 + 3), height * 0.37, Color("ca9d61"), true, -1, true)
		draw_arc(Vector2(x + width - 9, y + height * 0.5 + 3), height * 0.22, 0, TAU, 20, Color("966c42"), 2, true)
	else:
		var polygon := PackedVector2Array([Vector2(x, y + height), Vector2(x + 2, y + 19), Vector2(x + 16, y + 2), Vector2(x + width - 12, y), Vector2(x + width, y + 18), Vector2(x + width + 2, y + height)])
		draw_colored_polygon(polygon, Color("354640"))
		draw_colored_polygon(PackedVector2Array([polygon[1], polygon[2], polygon[3], Vector2(x + 25, y + height - 8)]), Color("667568"))
		draw_line(polygon[2], polygon[3], Color("99a079"), 3, true)
		draw_circle(Vector2(x + 10, y + height - 8), 3, Color("80905b"), true, -1, true)
	if obstacle.get("hit", false):
		draw_circle(Vector2(x + width / 2, y + height / 2), 4, Color("f5ca62"), true, -1, true)


func _hint(text: String, at: Vector2) -> void:
	var width := BODY.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_style_box(_style(Color(1, 0.98, 0.88, 0.9), 6), Rect2(at.x - width / 2 - 7, at.y - 15, width + 14, 22))
	draw_string(BOLD, at - Vector2(width / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)
