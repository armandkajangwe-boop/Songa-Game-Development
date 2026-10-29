extends SceneTree
## Run: godot --headless --path . --script tests/smoke.gd

const Model = preload("res://scripts/runner_model.gd")
var _checks := 0
var _failures := 0


func _initialize() -> void:
	_test_initial_state_and_pause()
	_test_collisions_and_grace()
	_test_jump_and_slide()
	_test_pickups()
	_test_restart()
	_test_determinism()
	_test_progression_and_generated_courses()
	print("Songa simulation: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)


func _blank(seed_value: int = 42):
	var model = Model.new(seed_value)
	model.begin()
	model._spawn_remaining = 1000000.0
	return model


func _advance(model, seconds: float, frame_delta: float = 1.0 / 60.0) -> void:
	for frame in range(roundi(seconds / frame_delta)):
		model.tick(frame_delta)


func _hazard(x: float, kind: String = "rock") -> Dictionary:
	if kind == "branch":
		return {"x": x, "y": 585.0, "width": 74.0, "height": 105.0, "kind": kind}
	if kind == "log":
		return {"x": x, "y": 702.0, "width": 64.0, "height": 38.0, "kind": kind}
	return {"x": x, "y": 692.0, "width": 42.0, "height": 48.0, "kind": kind}


func _snapshot(model) -> Array:
	return [model.phase, model.distance, model.elapsed, model.speed, model.player_y,
		model.velocity_y, model.ducking, model.lives, model.bananas, model.hit_flash,
		model.invulnerability, model.obstacles.duplicate(true), model.pickups.duplicate(true)]


func _test_initial_state_and_pause() -> void:
	var model = Model.new()
	_check(model.phase == Model.Phase.TITLE, "New model starts at the title")
	model.tick(0.2)
	model.jump()
	_check(model.distance == 0 and model.velocity_y == 0, "Title cannot advance or jump")
	model.begin()
	_advance(model, 1.0)
	model.jump()
	model.tick(1.0 / 60.0)
	model.toggle_pause()
	var frozen := _snapshot(model)
	_advance(model, 3.0)
	model.jump()
	_check(_snapshot(model) == frozen, "Pause freezes time, world, score and airborne player")
	model.toggle_pause()
	model.tick(1.0 / 60.0)
	_check(model.elapsed > float(frozen[2]), "Resume advances simulation")
	var before := _snapshot(model)
	model.tick(-1.0)
	model.tick(NAN)
	model.tick(INF)
	_check(_snapshot(model) == before, "Invalid deltas do not corrupt the simulation")


func _test_collisions_and_grace() -> void:
	var lingering = _blank()
	var wide_obstacle := _hazard(140.0)
	wide_obstacle["width"] = 1000.0
	lingering.obstacles.append(wide_obstacle)
	_advance(lingering, 3.0)
	_check(lingering.lives == 2, "An overlapping obstacle cannot hit again after grace expires")
	var hitch = _blank()
	hitch.elapsed = 100.0
	var thin_obstacle := _hazard(190.0)
	thin_obstacle["width"] = 1.0
	hitch.obstacles.append(thin_obstacle)
	hitch.tick(0.25)
	_check(hitch.lives == 2, "Fixed substeps detect a thin hazard crossed entirely during one slow frame")
	var model = _blank()
	model.obstacles.append(_hazard(160.0))
	model.tick(1.0 / 60.0)
	_check(model.lives == 2 and model.hit_flash > 0.0, "Ground collision removes a heart and flashes")
	model.obstacles.append(_hazard(160.0, "log"))
	model.tick(1.0 / 60.0)
	_check(model.lives == 2, "Grace protects against a second obstacle")
	_advance(model, 1.5)
	_check(model.lives == 2, "Each obstacle damages at most once")
	model.obstacles.append(_hazard(160.0))
	model.tick(1.0 / 60.0)
	_check(model.lives == 1, "A new collision after grace removes another heart")
	_advance(model, 1.5)
	model.obstacles.append(_hazard(160.0))
	model.tick(1.0 / 60.0)
	_check(model.lives == 0 and model.phase == Model.Phase.GAME_OVER, "Third collision ends the run")
	var frozen := _snapshot(model)
	_advance(model, 1.0)
	_check(_snapshot(model) == frozen, "Game over freezes the completed run")


func _test_jump_and_slide() -> void:
	for kind in ["rock", "log"]:
		var model = _blank()
		model.obstacles.append(_hazard(220.0, kind))
		model.jump()
		model.tick(1.0 / 60.0)
		var velocity: float = model.velocity_y
		model.jump()
		_check(model.velocity_y == velocity, "Airborne jump cannot create a double jump")
		_advance(model, 1.0)
		_check(model.lives == 3, "Timed jump clears %s" % kind)
		_check(model.is_grounded() and model.player_y == model.ground_y, "Jump lands exactly on the ground")
	var standing = _blank()
	standing.obstacles.append(_hazard(160.0, "branch"))
	standing.tick(1.0 / 60.0)
	_check(standing.lives == 2, "Low bamboo branch hits a standing gorilla")
	var sliding = _blank()
	sliding.obstacles.append(_hazard(220.0, "branch"))
	sliding.set_ducking(true)
	_advance(sliding, 1.0)
	_check(sliding.lives == 3 and sliding.ducking, "Held slide clears the entire branch")
	sliding.set_ducking(false)
	_check(not sliding.ducking, "Slide releases immediately")


func _test_pickups() -> void:
	var model = _blank()
	model.pickups.append({"x": 160.0, "y": 700.0})
	model.tick(1.0 / 60.0)
	_check(model.bananas == 1 and model.pickups.is_empty(), "Touching a banana collects and removes it")
	_advance(model, 0.5)
	_check(model.bananas == 1, "A banana scores only once")
	model.pickups.append({"x": 160.0, "y": 500.0})
	model.tick(1.0 / 60.0)
	_check(model.bananas == 1, "Distant banana cannot be collected without contact")


func _test_restart() -> void:
	var model = _blank()
	_advance(model, 2.0)
	model.obstacles.append(_hazard(160.0))
	model.tick(1.0 / 60.0)
	model.set_ducking(true)
	model.bananas = 7
	var personal_best: float = model.best_distance
	model.begin(42)
	_check(model.phase == Model.Phase.RUNNING and model.lives == 3, "Restart restores phase and hearts")
	_check(model.distance == 0 and model.elapsed == 0 and model.speed == 240.0, "Restart resets score, clock and speed")
	_check(model.bananas == 0 and model.hit_flash == 0 and model.invulnerability == 0, "Restart clears rewards and collision timers")
	_check(model.obstacles.is_empty() and model.pickups.is_empty(), "Restart removes the old course")
	_check(model.player_y == 740.0 and model.velocity_y == 0 and not model.ducking, "Restart resets pose and held slide")
	_check(model.best_distance == personal_best, "Restart preserves the personal best")
	model.reset_to_title()
	_check(model.phase == Model.Phase.TITLE and model.best_distance == personal_best, "Returning to title preserves the best")


func _test_determinism() -> void:
	var a = Model.new(77)
	var b = Model.new(77)
	a.begin()
	b.begin()
	a.invulnerability = 1000.0
	b.invulnerability = 1000.0
	_advance(a, 20.0, 1.0 / 60.0)
	_advance(b, 20.0, 1.0 / 30.0)
	_check(_snapshot(a) == _snapshot(b), "Same seed gives identical state at 30 and 60 FPS")
	var c = Model.new(78)
	c.begin()
	c.invulnerability = 1000.0
	_advance(c, 20.0)
	_check(c.obstacles != a.obstacles, "Different seeds produce different course spacing")
	a.begin()
	a.invulnerability = 1000.0
	_advance(a, 20.0)
	_check(_snapshot(a) == _snapshot(b), "Restarting the seed reproduces the course without RNG leakage")


func _test_progression_and_generated_courses() -> void:
	var progression = _blank()
	_advance(progression, 100.0)
	_check(progression.speed == Model.MAX_SPEED and progression.distance > 1200.0, "Speed increases to its safe cap and distance accumulates")
	# Play complete generated courses using only visible hazards. This exercises
	# transitions between jump and slide at starting and maximum difficulty.
	for seed_value in range(24):
		var model = Model.new(seed_value)
		model.begin()
		if seed_value >= 12:
			model.elapsed = 100.0
		for frame in range(60 * 45):
			var nearest: Dictionary = {}
			for obstacle in model.obstacles:
				if float(obstacle["x"]) + float(obstacle["width"]) >= model.player_x - 20.0:
					nearest = obstacle
					break
			var should_slide := false
			if not nearest.is_empty():
				var front: float = nearest["x"]
				if nearest["kind"] == "branch":
					should_slide = front < model.player_x + 110.0
				elif front < model.player_x + 20.0 + model.speed * 0.20 and model.is_grounded():
					model.jump()
			model.set_ducking(should_slide)
			model.tick(1.0 / 60.0)
		_check(model.lives == 3, "Generated course seed %d is traversable without damage" % seed_value)
		_check(model.bananas > 0, "Generated course seed %d has reachable banana trails" % seed_value)
