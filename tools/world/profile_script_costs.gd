extends SceneTree
## Diagnostic attribution only: explicit script ticks, no output artifacts.
## This is not a gameplay/FPS benchmark; physics and engine animation still run.
var totals: Dictionary = {}
var ticks: Array[Node] = []
var physics := false
var tick_method := "_process"
func _initialize() -> void:
	_run.call_deferred()
func collect(node: Node) -> void:
	if node.get_script() != null and node.has_method(tick_method) and (node.is_physics_processing() if physics else node.is_processing()):
		ticks.append(node)
		if physics: node.set_physics_process(false)
		else: node.set_process(false)
	for child in node.get_children(): collect(child)
func _run() -> void:
	physics = "--physics" in OS.get_cmdline_user_args()
	tick_method = "_physics_process" if physics else "_process"
	root.get_node("SaveManager").start_new_game()
	for frame in 4: await process_frame
	var world: Node3D = current_scene
	var opening := world.get_node("OpeningSequence")
	var skip := InputEventKey.new()
	skip.keycode = KEY_ESCAPE
	skip.pressed = true
	opening._input(skip)
	for frame in 2: await process_frame
	opening._input(skip)
	while opening.state != "done": await process_frame
	var actor: Node3D = world.get_node("Player")
	var location := Vector2(-310,245) if "--village" in OS.get_cmdline_user_args() else Vector2(640,235)
	actor.global_position = Vector3(location.x,world.layout.height(location.x,location.y)+1.1,location.y)
	collect(world)
	ticks.sort_custom(func(a,b): return a.process_physics_priority < b.process_physics_priority if physics else a.process_priority < b.process_priority)
	for frame in 120:
		for node in ticks:
			if not is_instance_valid(node) or node.is_queued_for_deletion(): continue
			var path: String = node.get_script().resource_path
			var start := Time.get_ticks_usec()
			node.call(tick_method,1.0/60.0)
			var elapsed := Time.get_ticks_usec()-start
			if not totals.has(path): totals[path] = {"path":path,"usec":0,"calls":0,"max_usec":0}
			var result: Dictionary = totals[path]
			result.usec += elapsed
			result.calls += 1
			result.max_usec = maxi(result.max_usec,elapsed)
		await process_frame
	var ranked: Array = totals.values()
	ranked.sort_custom(func(a,b): return a.usec > b.usec)
	for result in ranked.slice(0,20):
		result["ms_per_frame"] = float(result.usec)/120000.0
		print("SCRIPT COST ",JSON.stringify(result))
	print("SCRIPT COST PROFILE: COMPLETE | ",tick_method," explicitly ticked nodes ",ticks.size())
	await root.get_node("SaveManager").quit_game()
