extends SceneTree
## Scene-level integration tests. Keep their user data isolated:
## XDG_DATA_HOME=/tmp/songa-integration-test/data godot --headless --path . \
##   --script tests/integration.gd

const Model = preload("res://scripts/runner_model.gd")
const MainScene = preload("res://scenes/main.tscn")
const SAVE_PATH := "user://songa.cfg"

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Refuse to overwrite the developer's real progress, including when the test
	# is accidentally launched from the editor without its documented wrapper.
	if not OS.get_user_data_dir().contains("songa-integration-"):
		push_error("Integration tests require isolated XDG_DATA_HOME under /tmp/songa-integration-…")
		quit(1)
		return
	_remove_own_save()
	var game = _new_game()
	_check(game.title_screen.visible and not game.run_screen.visible, "Main scene opens on title")
	_check(not game.pause_screen.visible and not game.end_screen.visible, "Pause and results start hidden")
	_check(game.model.phase == Model.Phase.TITLE, "Main scene owns a title-phase simulation")
	_check(game.jump_button.disabled and game.slide_button.disabled, "Gameplay buttons are disabled at title")
	_check(game.hero.get_parent() == game and game.pursuer.is_pursuer, "Both differently configured gorillas enter the scene")
	_check(game.sound.enabled, "A fresh profile enables sound")
	game.sound.enabled = false

	_test_keyboard_and_buttons(game)
	_test_touch_gestures(game)
	_test_pause_and_focus(game)
	_test_focused_button_space(game)
	_test_lifecycle_persistence(game)
	_test_game_over_and_restart(game)
	_test_progress_roundtrip(game)
	game.free()
	_remove_own_save()
	print("Songa integration: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _new_game():
	var game = MainScene.instantiate()
	root.add_child(game)
	# The real callbacks are exercised explicitly to keep timing deterministic.
	game.set_physics_process(false)
	game.set_process(false)
	return game


func _start_blank(game) -> void:
	game._start_run()
	game.model._spawn_remaining = 1000000.0


func _key(code: Key, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event


func _touch(at: Vector2, index: int, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.index = index
	event.pressed = pressed
	return event


func _test_keyboard_and_buttons(game) -> void:
	game._input(_key(KEY_SPACE))
	game.model._spawn_remaining = 1000000.0
	_check(game.model.phase == Model.Phase.RUNNING and game.run_screen.visible, "Space starts the run and shows the HUD")
	_check(not game.title_screen.visible and not game.jump_button.disabled, "Starting hides title and enables controls")
	game._input(_key(KEY_SPACE))
	_check(game.model.velocity_y < 0.0, "Space input reaches the jump action")
	game._physics_process(1.0 / 60.0)
	_check(game.model.player_y < game.model.ground_y, "Scene physics advances the jumping simulation")

	_start_blank(game)
	game.slide_button.button_down.emit()
	game._physics_process(1.0 / 60.0)
	_check(game.model.ducking, "Slide button press reaches the simulation")
	game.slide_button.button_up.emit()
	game._physics_process(1.0 / 60.0)
	_check(not game.model.ducking, "Slide button release clears ducking")
	game.jump_button.button_down.emit()
	_check(game.model.velocity_y < 0.0, "Jump button press is connected to jump")


func _test_touch_gestures(game) -> void:
	_start_blank(game)
	game._unhandled_input(_touch(Vector2(390, 420), 3, true))
	_check(game.model.velocity_y == 0.0, "Touch down defers action until tap or swipe is known")
	game._unhandled_input(_touch(Vector2(390, 420), 8, false))
	_check(game._pointer_id == 3 and game.model.velocity_y == 0.0, "Unrelated finger release cannot complete a gesture")
	game._unhandled_input(_touch(Vector2(390, 420), 3, false))
	_check(game.model.velocity_y < 0.0 and game._pointer_id == -99, "A matching short touch becomes a jump")

	_start_blank(game)
	game._unhandled_input(_touch(Vector2(380, 350), 1, true))
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(380, 435)
	game._unhandled_input(drag)
	game._physics_process(1.0 / 60.0)
	_check(game.model.ducking and game.model.velocity_y == 0.0, "A down swipe produces a slide without jumping")
	game._update_characters()
	_check(game.hero.ducking and game.hero.scale.y < game.hero.scale.x and 72.0 * game.hero.scale.y < 50.0, "Crouched gorilla art fits under the 50px branch clearance")
	game._unhandled_input(_touch(Vector2(380, 435), 1, false))
	_check(game.model.velocity_y == 0.0 and game._slide_left > 0.0, "Swipe release keeps the timed slide and does not jump")
	for frame in range(60):
		game._physics_process(1.0 / 60.0)
	_check(not game.model.ducking and game._slide_left == 0.0, "A swipe slide expires without stuck input")
	game._update_characters()
	_check(is_equal_approx(game.hero.scale.x, game.hero.scale.y), "Standing restores the uncrouched visual scale")


func _test_pause_and_focus(game) -> void:
	_start_blank(game)
	game._input(_key(KEY_DOWN))
	game._slide_pressed = true
	game._slide_left = 0.5
	game._pointer_begin(Vector2(250, 400), 5)
	game._physics_process(1.0 / 60.0)
	_check(game.model.ducking, "Held keyboard and touch state reaches ducking")
	game._input(_key(KEY_P))
	_check(game.model.phase == Model.Phase.PAUSED and game.pause_screen.visible, "P opens the pause overlay")
	_check(not game._key_duck and not game._slide_pressed and game._slide_left == 0.0 and game._pointer_id == -99, "Pause clears every held input source")
	_check(not game.model.ducking and game.jump_button.disabled, "Pause clears pose and disables gameplay buttons")
	var elapsed: float = game.model.elapsed
	var distance: float = game.model.distance
	var animation_clock: float = game._clock
	game._physics_process(0.2)
	game._process(0.2)
	game._input(_key(KEY_SPACE))
	_check(game.model.elapsed == elapsed and game.model.distance == distance, "Paused callbacks freeze the simulation")
	_check(game.model.velocity_y == 0.0 and game._clock == animation_clock, "Paused jump and animation do not advance")
	game._input(_key(KEY_P))
	game._physics_process(1.0 / 60.0)
	_check(game.model.phase == Model.Phase.RUNNING and not game.pause_screen.visible and game.model.elapsed > elapsed, "P resumes an advancing run")
	_check(not game.model.ducking, "Resume does not restore stale held slide")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(game.model.phase == Model.Phase.PAUSED, "App losing focus automatically pauses the chase")
	game._toggle_pause()


func _test_game_over_and_restart(game) -> void:
	_start_blank(game)
	game.model.bananas = 4
	for hit in range(3):
		game.model.obstacles.clear()
		game.model.invulnerability = 0.0
		game.model.obstacles.append({"x": 155.0, "y": 692.0, "width": 42.0, "height": 48.0, "kind": "rock"})
		game._physics_process(1.0 / 60.0)
		_check(game.model.lives == 2 - hit, "Integrated collision %d removes exactly one heart" % (hit + 1))
	_check(game.model.phase == Model.Phase.GAME_OVER and game.end_screen.visible, "Three collisions show results")
	_check(game.result_bananas.text == "4" and game.result_distance.text.ends_with(" m"), "Result labels display the completed run")
	_check(game.jump_button.disabled and game.slide_button.disabled, "Results disable gameplay controls")
	_check(FileAccess.file_exists(SAVE_PATH), "Finishing the run saves local progress")
	var personal_best: float = game.model.best_distance
	game._start_run()
	_check(game.model.phase == Model.Phase.RUNNING and not game.end_screen.visible, "Run again returns to gameplay")
	_check(game.model.bananas == 0 and game.model.distance == 0.0 and game.model.lives == 3, "Restart clears run rewards, distance and damage")
	_check(game.model.best_distance == personal_best, "Restart retains the personal best")
	game._go_home()
	_check(game.title_screen.visible and not game.run_screen.visible and game.model.phase == Model.Phase.TITLE, "Back to camp restores the title")


func _find_button(parent: Node, text: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == text:
			return child
		var nested := _find_button(child, text)
		if nested != null:
			return nested
	return null


func _test_focused_button_space(game) -> void:
	_start_blank(game)
	var pause_button := _find_button(game.run_screen, "Ⅱ")
	_check(pause_button != null, "Gameplay has a focusable pause button")
	if pause_button == null:
		return
	pause_button.grab_focus()
	pause_button.pressed.emit()
	_check(game.model.phase == Model.Phase.PAUSED, "Focused pause button opens the pause menu")
	game._input(_key(KEY_P))
	_check(game.model.phase == Model.Phase.RUNNING and root.gui_get_focus_owner() == pause_button, "Keyboard resume retains GUI focus on the pause button")
	# Dispatch through the actual viewport, including GUI. Direct calls to
	# _input alone would miss Space's default ui_accept activation of a button.
	root.push_input(_key(KEY_SPACE), true)
	_check(game.model.phase == Model.Phase.RUNNING and game.model.velocity_y < 0.0, "Real Space press jumps without activating the focused pause button")
	root.push_input(_key(KEY_SPACE, false), true)
	_check(game.model.phase == Model.Phase.RUNNING and not game.pause_screen.visible, "Real Space release also leaves the chase running")
	pause_button.release_focus()


func _saved_best() -> float:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return -1.0
	return float(config.get_value("progress", "best_distance", -1.0))


func _test_lifecycle_persistence(game) -> void:
	_start_blank(game)
	game.model.best_distance = 312.5
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(_saved_best() == 312.5 and game.model.phase == Model.Phase.PAUSED, "Focus loss saves current best before pausing")
	game._toggle_pause()
	game.model.best_distance = 413.75
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(_saved_best() == 413.75 and game.model.phase == Model.Phase.PAUSED, "Mobile application suspension saves current best before pausing")
	game._toggle_pause()
	game.model.best_distance = 514.25
	game._toggle_pause()
	_check(_saved_best() == 514.25, "Explicit pause also preserves an unfinished run's best")
	game._toggle_pause()
	game.model.best_distance = 615.5
	game._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_check(_saved_best() == 615.5 and game.model.phase == Model.Phase.PAUSED, "Window close notification preserves current best")


func _test_progress_roundtrip(game) -> void:
	game.model.best_distance = 234.5
	game.sound.enabled = false
	game._save_progress()
	game.model.best_distance = 0.0
	game.sound.enabled = true
	game._load_progress()
	_check(game.model.best_distance == 234.5 and not game.sound.enabled, "Save/load roundtrips best distance and sound preference")
	var restored = _new_game()
	_check(restored.model.best_distance == 234.5 and not restored.sound.enabled, "A fresh scene restores the saved profile")
	_check(restored.sound_button.text == "SOUND OFF" and restored.menu_best.text.contains("234 m"), "Restored preferences are reflected in the title UI")
	restored._toggle_sound()
	_check(restored.sound.enabled and restored.sound_button.text == "SOUND ON", "Sound toggle updates the sound engine and label")
	var saved := ConfigFile.new()
	_check(saved.load(SAVE_PATH) == OK and saved.get_value("preferences", "sound", false), "Sound toggle persists its new preference")
	restored.sound.enabled = false
	restored.free()


func _remove_own_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
