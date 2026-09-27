extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var time := Node.new()
	time.name = "GameTimeSystem"
	time.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	host.add_child(time)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	host.add_child(actor)
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	if visual.motion_tree == null or not visual.motion_tree.active:
		push_error("ARJUN VISUAL TREE: motion tree did not start")
		quit(1)
		return
	actor.velocity.x = actor.walk_speed
	visual._process(0.2)
	if visual.motion_tree.ground_blend <= 0.5:
		push_error("ARJUN VISUAL TREE: player speed did not reach the tree")
		quit(1)
		return
	actor.is_swimming = true
	for i in 8: visual._process(0.1)
	if visual.model.rotation.x > 0.1 or visual.motion_tree.swim_blend < 0.9:
		push_error("ARJUN VISUAL TREE: swim clip received a second body tilt")
		quit(1)
		return
	actor.is_swimming = false
	actor.set_meta("mounted_vehicle", null)
	visual._process(0.2)
	if not visual.motion_tree.active:
		push_error("ARJUN VISUAL TREE: a cleared vehicle tag left locomotion disabled")
		quit(1)
		return
	print("ARJUN VISUAL TREE: PASS | player speed, ground blend, swim pitch, vehicle exit")
	quit()
