extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	for i in 12: await physics_frame
	var actor: CharacterBody3D = world.get_node("Player")
	var chest: Interactable = world.get_node("Settlement/ColonialCompound/SecludedSupplyChest")
	var stance: Node = actor.get_node("StealthStance")
	actor.global_position = chest.global_position+Vector3(0,1,1.1)
	actor.get_node("CameraPivot").rotation.y = 0.0
	for i in 8: await physics_frame
	stance.enter_prone()
	if stance.stance != "prone" or absf(actor.get_node("CollisionShape3D").rotation.x-PI*.5) > .01 or stance.move_speed() >= actor.walk_speed:
		push_error("STANCE BLOCKED: prone shape or crawl movement failed")
		quit(1)
		return
	if not stance.stand() or stance.stance != "":
		push_error("STANCE BLOCKED: cannot recover standing")
		quit(1)
		return
	if not stance.try_cover() or stance.stance != "cover":
		push_error("STANCE BLOCKED: chest cover not detected")
		quit(1)
		return
	Input.action_press("aim")
	if stance.camera_height() < 1.35 or not actor.get_node("CombatInput").available():
		push_error("STANCE BLOCKED: cannot aim and attack from cover")
		quit(1)
		return
	Input.action_release("aim")
	actor.global_position += Vector3(0,0,3)
	for i in 3: await physics_frame
	if stance.stance != "":
		push_error("STANCE BLOCKED: cover did not release after leaving")
		quit(1)
		return
	for kind in ["tree","cart"]:
		var obstacle := StaticBody3D.new()
		obstacle.name = "CoverTest_"+kind
		world.add_child(obstacle)
		obstacle.global_position = chest.global_position+Vector3(5 if kind == "tree" else 8,0,0)
		var collision := CollisionShape3D.new()
		if kind == "tree":
			var cylinder := CylinderShape3D.new()
			cylinder.radius = .55
			cylinder.height = 2.8
			collision.shape = cylinder
			collision.position.y = 1.4
		else:
			var box := BoxShape3D.new()
			box.size = Vector3(2.3,1.2,1.1)
			collision.shape = box
			collision.position.y = .6
		obstacle.add_child(collision)
		actor.global_position = obstacle.global_position+Vector3(0,1,1.22)
		actor.get_node("CameraPivot").global_rotation = Vector3.ZERO
		for i in 15: await physics_frame
		if not stance.try_cover() or stance.cover_body != obstacle:
			var facing: Vector3 = -actor.get_node("CameraPivot").global_basis.z
			var ray := PhysicsRayQueryParameters3D.create(actor.global_position-Vector3.UP*.18,actor.global_position-Vector3.UP*.18+facing*1.5)
			ray.exclude = [actor.get_rid()]
			push_error("STANCE BLOCKED: "+kind+" cover not detected; floor="+str(actor.is_on_floor())+" at "+str(actor.global_position)+" obstacle="+str(obstacle.global_position)+" facing="+str(facing)+" hit="+str(actor.get_world_3d().direct_space_state.intersect_ray(ray)))
			quit(1)
			return
		stance.stand()
	print("STEALTH STANCE: PASS | prone, stand clearance, crate/tree/cart cover, cover release")
	quit()
