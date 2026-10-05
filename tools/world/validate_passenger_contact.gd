extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var world := Node3D.new(); root.add_child(world); current_scene = world
	var actor := preload("res://characters/npcs/households/household_npc_actor.gd").new()
	actor.movement_enabled = false
	var doc := GLTFDocument.new(); var state := GLTFState.new()
	assert(doc.append_from_file(ProjectSettings.globalize_path("res://WorkingAssets/NPCs/errand_passenger/errand_passenger.glb"),state)==OK)
	actor.add_child(doc.generate_scene(state)); world.add_child(actor)
	actor.set_process(false); actor.animation_tree.active = false
	var cart := preload("res://vehicles/horse_cart_candidate.gd").new(); world.add_child(cart)
	for frame in 3: await process_frame
	for side in [-1.0,1.0]:
		actor.global_position = cart.to_global(Vector3(side*1.12,0,1.4)); actor.global_rotation.y = PI
		var rig: Skeleton3D = actor.get("_skeleton")
		var hip: Vector3 = rig.to_global(rig.get_bone_global_pose(rig.find_bone("pelvis")).origin)
		actor.global_position += cart.to_global(Vector3(side*1.12,1.48,1.50))-hip
		preload("res://world/suryagarh/errands/passenger_contact.gd").grip(actor,cart,side,1.0)
		print("FOCUSED_GRIP side ",side," error ",actor.get_meta("passenger_palm_error_m")," normal ",actor.get_meta("passenger_palm_normal_dot"))
	quit()
