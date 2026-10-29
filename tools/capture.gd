extends SceneTree
## Capture the actual renderer in deterministic, staged presentation states.
## godot --path . --script tools/capture.gd -- --output=/absolute/directory

const Main = preload("res://scenes/main.tscn")
var _game: Node2D
var _directory := "res://artifacts"


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_directory = argument.trim_prefix("--output=")
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Screenshots require a display and renderer, not headless mode.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_directory)
	_game = Main.instantiate()
	root.add_child(_game)
	_game.set_process(false)
	_game.set_physics_process(false)
	_game.sound.enabled = false
	await _save("title.png")
	_game._start_run()
	_game.model.distance = 142.0
	_game.model.bananas = 7
	_game.model.elapsed = 12.0
	_game.model.obstacles.assign([{"x": 355.0, "y": 692.0, "width": 42.0, "height": 48.0, "kind": "rock", "passed": false, "hit": false}])
	_game.model.pickups.assign([{"x": 319.0, "y": 630.0}, {"x": 355.0, "y": 605.0}, {"x": 391.0, "y": 630.0}])
	_game._clock = 0.6
	_game._process(0.0)
	await _save("running.png")
	_game.model.set_ducking(true)
	_game.model.obstacles.assign([{"x": 130.0, "y": 585.0, "width": 74.0, "height": 105.0, "kind": "branch", "passed": false, "hit": false}])
	_game.model.pickups.clear()
	_game._process(0.0)
	await _save("sliding.png")
	_game._toggle_pause()
	await _save("paused.png")
	_game.free()
	print("Captured renderer screenshots in ", _directory)
	quit(0)


func _save(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(_directory.path_join(filename))
	if error != OK:
		push_error("Screenshot save failed: " + error_string(error))
		quit(1)
