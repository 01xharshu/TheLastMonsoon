extends CanvasLayer
## Opt-in, low-frequency engine diagnostics; no profiler or system CPU estimate.
var panel: PanelContainer
var label: Label
var elapsed := 0.0
var frame_sum := 0.0
var frame_count := 0
var worst_frame := 0.0
var previous_tick := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 140
	panel = PanelContainer.new()
	panel.name = "PerformancePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -392
	panel.offset_right = -12
	panel.offset_top = -70
	panel.offset_bottom = 70
	panel.custom_minimum_size = Vector2(380, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.02, 0.025, 0.025, 0.85)
	background.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", background)
	add_child(panel)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 15)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	panel.visible = false

func _process(_delta: float) -> void:
	var enabled := bool(SaveManager.options.get("developer_performance", false))
	panel.visible = enabled
	if not enabled:
		elapsed = 0.0
		frame_sum = 0.0
		frame_count = 0
		worst_frame = 0.0
		previous_tick = 0
		return
	var now := Time.get_ticks_usec()
	if previous_tick == 0:
		previous_tick = now
		return
	var frame_ms := (now - previous_tick) / 1000.0
	previous_tick = now
	frame_sum += frame_ms
	frame_count += 1
	worst_frame = maxf(worst_frame, frame_ms)
	elapsed += frame_ms / 1000.0
	if elapsed < 0.5: return
	var average := frame_sum / maxi(frame_count, 1)
	label.text = "PERFORMANCE  ·  %d FPS\nFrame  %.1f ms avg  /  %.1f ms worst\nCPU engine  process %.1f ms  /  physics %.1f ms\nDraw calls  %d  ·  objects  %d\nEngine memory  %.1f MiB  ·  CPU %% unavailable" % [
		Engine.get_frames_per_second(), average, worst_frame,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0]
	elapsed = 0.0
	frame_sum = 0.0
	frame_count = 0
	worst_frame = 0.0
