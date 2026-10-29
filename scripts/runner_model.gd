class_name RunnerModel
extends RefCounted
## Deterministic, scene-independent simulation in a 540 × 960 portrait world.
## Positions are pixels; distance is metres (20 world pixels = one metre).

enum Phase { TITLE, RUNNING, PAUSED, GAME_OVER }

const STEP := 1.0 / 120.0
const START_SPEED := 240.0
const MAX_SPEED := 350.0
const GRAVITY := 1850.0
const JUMP_SPEED := -680.0
const PLAYER_WIDTH := 40.0
const STANDING_HEIGHT := 80.0
const DUCK_HEIGHT := 32.0
const INVULNERABLE_SECONDS := 1.35

var phase: Phase = Phase.TITLE
var distance := 0.0
var elapsed := 0.0
var speed := START_SPEED
var best_distance := 0.0
var ground_y := 740.0
var player_x := 155.0
var player_y := 740.0
var velocity_y := 0.0
var ducking := false
var lives := 3
var bananas := 0
var hit_flash := 0.0
var invulnerability := 0.0
var chase_pressure := 0.18
var obstacles: Array[Dictionary] = []
var pickups: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _run_seed := 1308
var _accumulator := 0.0
var _spawn_remaining := 180.0
var _pattern_count := 0
var _duck_held := false


func _init(seed_value: int = 1308) -> void:
	_run_seed = seed_value
	_rng.seed = _run_seed


## With no seed argument a restart repeats the same course. Pass a new seed for
## a fresh course. Personal best deliberately survives begin/reset_to_title.
func begin(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_run_seed = seed_value
	_rng.seed = _run_seed
	phase = Phase.RUNNING
	distance = 0.0
	elapsed = 0.0
	speed = START_SPEED
	player_y = ground_y
	velocity_y = 0.0
	ducking = false
	_duck_held = false
	lives = 3
	bananas = 0
	hit_flash = 0.0
	invulnerability = 0.0
	chase_pressure = 0.18
	obstacles.clear()
	pickups.clear()
	_accumulator = 0.0
	_spawn_remaining = 180.0
	_pattern_count = 0


func reset_to_title() -> void:
	begin()
	phase = Phase.TITLE


func toggle_pause() -> void:
	if phase == Phase.RUNNING:
		phase = Phase.PAUSED
	elif phase == Phase.PAUSED:
		phase = Phase.RUNNING


func jump() -> void:
	if phase == Phase.RUNNING and is_grounded():
		velocity_y = JUMP_SPEED
		ducking = false


func set_ducking(held: bool) -> void:
	# Release must work while paused, so a lifted finger cannot leave a stuck slide.
	_duck_held = held if phase == Phase.RUNNING else false
	ducking = _duck_held and is_grounded()


func is_grounded() -> bool:
	return player_y >= ground_y - 0.01 and velocity_y >= 0.0


func player_rect() -> Rect2:
	var height := DUCK_HEIGHT if ducking else STANDING_HEIGHT
	return Rect2(player_x - PLAYER_WIDTH * 0.5, player_y - height, PLAYER_WIDTH, height)


func obstacle_rect(obstacle: Dictionary) -> Rect2:
	var height := float(obstacle["height"])
	var top := float(obstacle.get("y", ground_y - height))
	if obstacle["kind"] == "branch" and not obstacle.has("y"):
		top = ground_y - 155.0
	return Rect2(float(obstacle["x"]), top, float(obstacle["width"]), height)


func tick(delta: float) -> void:
	if phase != Phase.RUNNING or not is_finite(delta) or delta <= 0.0:
		return
	# Bound work after a suspended browser tab. Fixed substeps prevent tunnelling
	# and make obstacle generation independent of ordinary render frame rates.
	_accumulator += minf(delta, 0.25)
	while _accumulator + 0.0000001 >= STEP and phase == Phase.RUNNING:
		_accumulator -= STEP
		_step()


func _step() -> void:
	elapsed += STEP
	speed = minf(MAX_SPEED, START_SPEED + elapsed * 1.4)
	var movement := speed * STEP
	distance += movement / 20.0
	best_distance = maxf(best_distance, distance)
	hit_flash = maxf(0.0, hit_flash - STEP)
	invulnerability = maxf(0.0, invulnerability - STEP)
	if not is_grounded():
		player_y += velocity_y * STEP + 0.5 * GRAVITY * STEP * STEP
		velocity_y += GRAVITY * STEP
		if player_y >= ground_y:
			player_y = ground_y
			velocity_y = 0.0
	ducking = _duck_held and is_grounded()

	_spawn_remaining -= movement
	if _spawn_remaining <= 0.0:
		_spawn_pattern()
	var body := player_rect()
	for obstacle in obstacles:
		obstacle["x"] = float(obstacle["x"]) - movement
		if not obstacle.get("hit", false) and body.intersects(obstacle_rect(obstacle)):
			# Consume the encounter even during grace: never damage twice on one item.
			obstacle["hit"] = true
			if invulnerability <= 0.0:
				_take_hit()
		if float(obstacle["x"]) + float(obstacle["width"]) < player_x - PLAYER_WIDTH * 0.5:
			obstacle["passed"] = true
	for pickup in pickups:
		pickup["x"] = float(pickup["x"]) - movement
		if not pickup.get("collected", false):
			var center := Vector2(float(pickup["x"]), float(pickup["y"]))
			if body.grow(10.0).has_point(center):
				pickup["collected"] = true
				bananas += 1
	obstacles = obstacles.filter(func(item: Dictionary) -> bool: return float(item["x"]) + float(item["width"]) > -80.0)
	pickups = pickups.filter(func(item: Dictionary) -> bool: return float(item["x"]) > -40.0 and not item.get("collected", false))
	chase_pressure = clampf(0.18 + (3 - lives) * 0.27 + elapsed * 0.0007, 0.18, 0.92)


func _take_hit() -> void:
	lives -= 1
	hit_flash = 0.45
	invulnerability = INVULNERABLE_SECONDS
	if lives <= 0:
		lives = 0
		phase = Phase.GAME_OVER
		_duck_held = false
		ducking = false


func _spawn_pattern() -> void:
	# Two introductory ground hazards teach jumping before the first slide.
	var kind := "rock"
	if _pattern_count == 1:
		kind = "log"
	elif _pattern_count == 2:
		kind = "branch"
	elif _pattern_count > 2:
		kind = ["rock", "log", "branch"][_rng.randi_range(0, 2)]
	var width := 42.0
	var height := 48.0
	if kind == "log":
		width = 64.0
		height = 38.0
	elif kind == "branch":
		width = 74.0
		height = 105.0
	var top := ground_y - height if kind != "branch" else ground_y - 155.0
	var x := 640.0
	obstacles.append({"x": x, "y": top, "width": width, "height": height,
		"kind": kind, "passed": false, "hit": false})
	for index in range(3):
		var pickup_y := ground_y - 110.0 - (25.0 if index == 1 else 0.0)
		if kind == "branch":
			pickup_y = ground_y - 18.0
		pickups.append({"x": x - 36.0 + index * 36.0, "y": pickup_y, "collected": false})
	# At maximum speed this still leaves >1 second between the end of a jump
	# and the next encounter. Difficulty comes from speed, not impossible pairs.
	_spawn_remaining += speed * _rng.randf_range(1.9, 2.5) + width
	_pattern_count += 1
