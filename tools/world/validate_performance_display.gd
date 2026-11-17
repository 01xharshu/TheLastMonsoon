extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var manager := root.get_node("SaveManager")
	manager.settings_path = "user://performance_display_test.cfg"
	var panel = load("res://ui/settings_panel.gd").new()
	root.add_child(panel)
	panel.show_category("Developer")
	var toggle: CheckButton
	for child in panel.get_children():
		if child is CheckButton: toggle = child
	if toggle == null or toggle.button_pressed:
		push_error("PERFORMANCE DISPLAY: missing or enabled by default")
		quit(1); return
	toggle.button_pressed = true
	var display = root.get_node("PerformanceDisplay")
	var until := Time.get_ticks_msec() + 800
	while Time.get_ticks_msec() < until: await process_frame
	if not "FPS" in display.label.text or not "CPU engine" in display.label.text:
		push_error("PERFORMANCE DISPLAY: counters missing")
		quit(1); return
	if OS.has_environment("TLM_PERF_IMAGE"):
		await process_frame
		root.get_texture().get_image().save_png(OS.get_environment("TLM_PERF_IMAGE"))
	if display.panel.anchor_right != 1.0 or display.panel.anchor_top != 0.5 or display.panel.offset_right != -12.0:
		push_error("PERFORMANCE DISPLAY: right-center placement failed")
		quit(1); return
	if not manager.options.developer_performance or not display.panel.visible:
		push_error("PERFORMANCE DISPLAY: toggle failed")
		quit(1); return
	manager.options.developer_performance = false
	manager.load_options()
	if not manager.options.developer_performance:
		push_error("PERFORMANCE DISPLAY: setting was not persisted")
		quit(1); return
	toggle.button_pressed = false
	await process_frame
	if display.panel.visible:
		push_error("PERFORMANCE DISPLAY: disable failed")
		quit(1); return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.settings_path))
	print("PERFORMANCE DISPLAY: PASS | toggle, persistence, disable")
	quit(0)
