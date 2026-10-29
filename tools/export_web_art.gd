extends SceneTree
## Export the same native illustration used by the Godot prototype for its
## standalone Canvas preview. Requires a real renderer; no project code changes.
## DISPLAY=:99 godot --rendering-method gl_compatibility --audio-driver Dummy \
##   --path . --script tools/export_web_art.gd

const Gorilla = preload("res://scripts/gorilla_art.gd")
const Backdrop = preload("res://scripts/mountain_backdrop.gd")
const OUTPUT := "res://web/assets"
const FRAME_SIZE := Vector2i(160, 160)
const FEET := Vector2(80, 148)
const FRAME_COUNT := 8

var _failures := 0


func _initialize() -> void:
	call_deferred("_export")


func _export() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Web illustration export requires a real renderer and display.")
		quit(1)
		return
	var error := DirAccess.make_dir_recursive_absolute(OUTPUT)
	if error != OK:
		push_error("Cannot create illustration directory: " + error_string(error))
		quit(1)
		return
	await _run_atlas("hero_run.png", false)
	await _pose("hero_air.png", true, false)
	await _pose("hero_slide.png", false, true)
	await _run_atlas("adult_run.png", true)
	await _backdrop()
	print("Web art: 160×160 frames, eight-frame 1280×160 run atlases; feet at (80,148).")
	print("Web art export: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _viewport(size: Vector2i, transparent: bool = true) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = transparent
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	root.add_child(viewport)
	return viewport


func _run_atlas(filename: String, adult: bool) -> void:
	var viewport := _viewport(Vector2i(FRAME_SIZE.x * FRAME_COUNT, FRAME_SIZE.y))
	for frame in range(FRAME_COUNT):
		var gorilla = Gorilla.new()
		gorilla.position = FEET + Vector2(float(frame * FRAME_SIZE.x), 0.0)
		gorilla.run_time = float(frame) * TAU / (13.0 * float(FRAME_COUNT))
		gorilla.is_pursuer = adult
		viewport.add_child(gorilla)
	await _save(viewport, filename)
	viewport.free()


func _pose(filename: String, air: bool, slide: bool) -> void:
	var viewport := _viewport(FRAME_SIZE)
	var gorilla = Gorilla.new()
	gorilla.position = FEET
	gorilla.airborne = air
	gorilla.ducking = slide
	if slide:
		gorilla.scale.y = 0.64 / 0.84
	viewport.add_child(gorilla)
	await _save(viewport, filename)
	viewport.free()


func _backdrop() -> void:
	var viewport := _viewport(Vector2i(540, 960), false)
	var backdrop = Backdrop.new()
	backdrop.scroll_distance = 0.0
	backdrop.animation_time = 0.0
	viewport.add_child(backdrop)
	await _save(viewport, "backdrop.png")
	viewport.free()


func _save(viewport: SubViewport, filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var error := image.save_png(OUTPUT.path_join(filename))
	if error != OK:
		_failures += 1
		push_error("Could not export %s: %s" % [filename, error_string(error)])
	else:
		print("Exported ", filename, " ", image.get_width(), "×", image.get_height())
