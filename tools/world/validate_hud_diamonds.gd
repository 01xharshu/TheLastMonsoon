extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var gauge: Control = load("res://player/circular_stat.gd").new()
	root.add_child(gauge)
	gauge.size = Vector2(48,48)
	for value in [0.0,1.0,20.0,50.0,100.0]:
		gauge.set_stat_value(value,100)
		for i in 2: await process_frame
		RenderingServer.force_draw()
	print("DIAMOND EXTREMES PASS")
	quit()
