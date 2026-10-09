extends Node3D
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := preload("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	add_child(world)
	for i in 4: await get_tree().physics_frame
	var actor: CharacterBody3D = world.get_node("Player")
	actor.set_physics_process(false)
	var climb: Node = actor.get_node("ClimbComponent")
	climb.set_physics_process(false)
	var windows := get_tree().get_nodes_in_group("climbable_windows")
	print("WINDOW WORLD ready | registered=",windows.size())
	var single_window := OS.get_cmdline_user_args().has("--single-window")
	var open_windows := 0
	var paired := 0
	for portal in windows:
		if portal.get_parent().get_meta("window_access","") != "open": continue
		if single_window and open_windows > 0: continue
		open_windows += 1
		var both := true
		for direction in [-1.0,1.0]:
			var crossed := false
			for lane in [0.0,.5,-.5]:
				if await _cross(actor,climb,portal,direction,lane):
					crossed = true
					break
			print("WINDOW WORLD direction | ",portal.get_path()," side=",direction," crossed=",crossed)
			if not crossed:
				print("WINDOW WORLD blocked: ",portal.get_path()," side=",direction)
				both = false
		if both: paired += 1
	var passed := open_windows >= (1 if single_window else 8) and paired == open_windows
	print("WINDOW WORLD: ","PASS" if passed else "FAIL"," | registered=",windows.size()," open=",open_windows," crossed_both_ways=",paired," normal_Space_and_cloth=true")
	world.queue_free()
	for frame in 3: await get_tree().physics_frame
	get_tree().quit(0 if passed else 1)

func _cross(actor: CharacterBody3D, climb: Node, portal: Node3D, direction: float, lane: float) -> bool:
	actor.set_physics_process(false)
	climb.set_physics_process(false)
	var normal: Vector3 = portal.global_basis.x.normalized()*direction
	var at: Vector3 = portal.global_position+normal*.9+portal.global_basis.z.normalized()*lane
	var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP,at-Vector3.UP*2.0)
	query.exclude = [actor.get_rid()]
	var floor_hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if floor_hit.is_empty(): return false
	actor.global_position = Vector3(at.x,floor_hit.position.y+.94,at.z)
	actor.velocity = Vector3.ZERO
	actor.visual_root.global_rotation.y = atan2(-normal.x,-normal.z)
	actor.camera_pivot.global_rotation.y = actor.visual_root.global_rotation.y
	for frame in 4: await get_tree().physics_frame
	var visual: Node = actor.get_node("VisualRoot/CharacterVisual")
	var tunic := visual.model.find_child("Arjun_Kurta_SplitHem",true,false) as MeshInstance3D
	var original_tunic: Mesh = tunic.mesh
	actor.set_physics_process(true)
	climb.set_physics_process(true)
	# Let a teleported test actor establish floor contact before pressing jump.
	for frame in 8: await get_tree().physics_frame
	var press := InputEventAction.new()
	press.action = "jump"
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().create_timer(.12).timeout
	press = InputEventAction.new()
	press.action = "jump"
	Input.parse_input_event(press)
	var started: bool = climb.window.active and climb.window.profile == "window"
	var gathered := false
	for frame in 300:
		await get_tree().physics_frame
		started = started or (climb.window.active and climb.window.profile == "window")
		if started and tunic.mesh != original_tunic and tunic.mesh.get_blend_shape_count() > 0:
			gathered = gathered or tunic.get_blend_shape_value(0) > .9
		if started and not climb.active: break
	actor.set_physics_process(false)
	climb.set_physics_process(false)
	if not started: return false
	if climb.active or climb.window.active or actor.collision_mask == 0 or actor.get_meta("climbing",false):
		push_error("WINDOW WORLD: input crossing failed to restore collision")
		get_tree().quit(1)
		return false
	if not gathered or tunic.mesh != original_tunic:
		push_error("Main-world crossing missed garment fold/restoration")
		get_tree().quit(1)
		return false
	return (actor.global_position-portal.global_position).dot(normal) < -.8
