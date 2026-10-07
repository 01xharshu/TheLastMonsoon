extends SceneTree
## Small regression for the first intro frame and physical render-pixel budget.
var failed := false
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var manager = root.get_node("SaveManager")
	for frame in 2: await process_frame
	var initial_pixels: Vector2i = root.get_texture().get_size()
	for repeat in 3:
		manager.apply_options()
		for frame in 2: await process_frame
	check(Vector2i(root.get_texture().get_size()) == initial_pixels,"Applying unchanged settings enlarged the viewport")
	manager._update_render_budget()
	print("RENDER SIZE | initial ",initial_pixels," current ",root.get_texture().get_size()," window ",DisplayServer.window_get_size()," viewport ",root.size," scale ",root.scaling_3d_scale," requested ",manager.render_scale_for_size(root.get_texture().get_size(),int(manager.options.graphics_quality)))
	check(is_equal_approx(root.scaling_3d_scale,manager.render_scale_for_size(root.get_texture().get_size(),int(manager.options.graphics_quality))),"Root viewport ignored physical pixels")
	for spec in [[Vector2i(1280,720),2,1.0],[Vector2i(5120,2880),2,.375],[Vector2i(5120,2880),1,.25],[Vector2i(1920,1080),0,.5],[Vector2i(2560,1080),2,.75]]:
		check(is_equal_approx(manager.render_scale_for_size(spec[0],spec[1]),spec[2]),"Wrong render budget: " + str(spec))
	var opening = load("res://story/opening_sequence.gd").new()
	root.add_child(opening)
	opening.set_process(false)
	opening._build_overlay()
	check(opening.shade.color == Color.BLACK,"White first intro frame")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var pixels := root.get_texture().get_image()
		check(pixels.get_pixel(pixels.get_width()/2,pixels.get_height()/2).r < .01,"Intro centre is not black")
		pixels.save_png("res://docs/world/captures/intro_initial_black.png")
	opening.free()
	var menu = load("res://ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for frame in 3: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/title_error_review.png")
	print("INTRO / RENDER BUDGET: ","FAIL" if failed else "PASS")
	preload("res://tools/test_audio_cleanup.gd").stop(root)
	await preload("res://tools/test_audio_cleanup.gd").settle(self)
	quit(1 if failed else 0)
