extends "res://tools/world/validate_police_arrest.gd"
## Deterministic Metal capture of the real station route; original motion speed.
var isolated_render := false
var finished_custody := false
func _initialize() -> void:
	process_frame.connect(draw_motion)
	super._initialize()
func draw_motion() -> void:
	if is_instance_valid(police) and not isolated_render:
		for mesh in world.find_children("*","MeshInstance3D",true,false):
			if not police.is_ancestor_of(mesh) and not actor.is_ancestor_of(mesh): mesh.hide()
		isolated_render=true
	if is_instance_valid(camera) and is_instance_valid(actor) and is_instance_valid(coordinator) and coordinator.phase!="idle":
		var offset:=Vector3(-2.4,1.25,2.6)
		if coordinator.phase=="restraint":offset=Vector3(2.0,.85,-2.0)
		if coordinator.phase in ["enter_cell","custody","stand"]:
			camera.global_position=police.to_global(Vector3(9.4,1.35,15.6))
			camera.look_at(police.to_global(Vector3(7.2,.9,14.7)))
		elif coordinator.phase in ["leave_cell","return"]:
			camera.global_position=police.to_global(Vector3(9.8,1.5,17.5))
			camera.look_at(actor.global_position)
		else:
			camera.global_position=actor.global_position+police.global_basis*offset
			camera.look_at(actor.global_position)
	if is_instance_valid(camera) and is_instance_valid(actor) and is_instance_valid(police) and coordinator.phase!="idle":
		var ignored: Array[RID]=[actor.get_rid()]
		for person in police.get_node("ThanaStaff").get_children():
			if person.has_method("palm_world"):ignored.append(person.body_collider.get_rid())
		var sight:=PhysicsRayQueryParameters3D.create(actor.global_position,camera.global_position,1)
		sight.exclude=ignored
		if not police.get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
			for alternate in [Vector3(-2.4,1.25,-2.6),Vector3(2.4,1.25,2.6),Vector3(2.4,1.25,-2.6)]:
				var at: Vector3=actor.global_position+police.global_basis*alternate
				sight.to=at
				if police.get_world_3d().direct_space_state.intersect_ray(sight).is_empty():camera.global_position=at;camera.look_at(actor.global_position);break
	if is_instance_valid(coordinator):
		if coordinator.phase=="custody":finished_custody=true
		if finished_custody and coordinator.phase=="return" and coordinator.phase_age>3:coordinator.officer.travel_speed=0;quit()
	RenderingServer.force_draw(false)
