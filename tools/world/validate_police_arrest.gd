extends SceneTree
var errors: Array[String]=[]
var phases: Array[String]=[]
var world: Node3D
var actor: CharacterBody3D
var police: Node3D
var coordinator: Node
var camera: Camera3D
var captures := false
var max_contact := 0.0
var max_step := 0.0
var last_position := Vector3.ZERO
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value: errors.append(message)
func snap(label: String) -> void:
	if not captures:return
	camera.global_position=actor.global_position+police.global_basis*Vector3(-2.2,1.1,2.4)
	camera.look_at(actor.global_position)
	if label=="custody":
		camera.global_position=police.to_global(Vector3(8.35,1.2,15.65))
		camera.look_at(police.to_global(Vector3(7.2,.9,14.7)))
	for i in 2:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/characters/arjun/arrest_sequence_%s.png"%label)
	if label in ["restraint","escort"]:
		camera.global_position=actor.global_position+police.global_basis*Vector3(2.0,.8,-2.5)
		camera.look_at(actor.global_position)
		for i in 2: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/characters/arjun/arrest_sequence_%s_back.png"%label+"")
func measure_step() -> void:
	max_step=maxf(max_step,actor.global_position.distance_to(last_position))
	last_position=actor.global_position
func run() -> void:
	world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	actor=world.get_node("Player")
	police=world.get_node("Settlement/DistrictPolice")
	coordinator=police.get_node_or_null("ThanaStaff/ArrestCoordinator")
	if coordinator==null: print("POLICE ARREST FAIL missing coordinator");quit(1);return
	captures=DisplayServer.get_name()!="headless"
	if captures:
		root.size=Vector2i(1280,720)
		root.content_scale_size=root.size
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
		actor.get_node("UI").hide()
		world.get_node("LandscapeUI").hide()
		camera=Camera3D.new()
		camera.fov=62
		world.add_child(camera)
		camera.make_current()
	actor.global_position=police.to_global(Vector3(9.5,.9,9))
	actor.global_basis=police.global_basis
	actor.get_node("VisualRoot").rotation.y=0
	for i in 12:await physics_frame
	if captures:
		for role in ["Daroga","Mohurrir","Burkundaz"]:
			var person: Node3D=police.get_node("ThanaStaff/"+role)
			camera.global_position=person.global_position+person.global_basis*Vector3(1.3,1.3,2.1)
			for offset in [Vector3(1.6,1.2,1.6),Vector3(-1.6,1.2,1.6),Vector3(1.6,1.2,-1.6),Vector3(-1.6,1.2,-1.6)]:
				var at: Vector3=person.global_position+police.global_basis*offset
				var sight:=PhysicsRayQueryParameters3D.create(at,person.global_position+Vector3.UP*.9,1)
				sight.exclude=[person.body_collider.get_rid()]
				if person.get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
					camera.global_position=at;break
			camera.look_at(person.global_position+Vector3.UP*.9)
			for frame in 2: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/characters/npcs/thana_%s_uniform.png"%role.to_lower())
	coordinator.custody_seconds=3.0
	coordinator.phase_changed.connect(func(value: String): phases.append(value); print("ARREST PHASE ",value))
	check(not coordinator.report_crime(actor,"unknown",actor.global_position),"Unknown offence accepted")
	# A real damage receiver forwards the witnessed offence, rather than a test-only arrest call.
	police.get_node("ThanaStaff/Daroga").take_damage(1.0)
	await process_frame
	check(coordinator.phase=="approach","Witnessed assault failed to trigger")
	if coordinator.phase!="approach":print("POLICE ARREST FAIL ",errors);quit(1);return
	last_position=actor.global_position
	physics_frame.connect(measure_step)
	var captured: Array[String]=[]
	for tick in 5400:
		await physics_frame
		if coordinator.phase=="restraint" and coordinator.phase_age>1.7:
			max_contact=maxf(max_contact,coordinator.officer.hand_contact_error)
			if tick%30==0: print("ARREST CONTACT ",coordinator.officer.hand_contact_error," officer ",police.to_local(coordinator.officer.global_position)," player ",police.to_local(actor.global_position))
		if coordinator.phase=="custody" and coordinator.phase_age>1.5:
			check(police.get_node("GroundCell0Gate").locked,"Cell gate failed to lock")
		if coordinator.phase in ["restraint","escort","custody","stand","leave_cell"] and coordinator.phase_age>(.6 if coordinator.phase=="stand" else 1.7) and coordinator.phase not in captured:
			captured.append(coordinator.phase)
			await snap(coordinator.phase)
		if coordinator.phase=="idle" and "custody" in phases:break
		if coordinator.phase=="idle" and tick>20:break
	check("escort" in phases and "custody" in phases and "stand" in phases and "leave_cell" in phases,"Sequence incomplete")
	check(coordinator.phase=="idle","Arrest did not finish")
	check(actor.get_meta("detention_action","")=="","Release left player locked")
	check(not police.get_node("GroundCell0Gate").locked,"Release left cell locked")
	check(max_contact<.025,"Officer restraint palm misses wrist")
	check(max_step<.16,"Escort teleported instead of walking")
	check(not coordinator.route_blocked,"Escort formation intersected solids")
	physics_frame.disconnect(measure_step)
	# Exercise the real pickup hook and dead-witness rejection after the full route.
	actor.global_position=police.to_global(Vector3(9.5,.9,9))
	actor.global_basis=police.global_basis
	for frame in 70:await physics_frame
	coordinator.cooldown=0
	check(not coordinator.report_crime(actor,"assault",police.to_global(Vector3(40,0,40))),"Outside offence accepted")
	for role in ["Daroga","Burkundaz"]: police.get_node("ThanaStaff/"+role).set_meta("dead",true)
	check(not coordinator.report_crime(actor,"theft",actor.global_position),"Dead witnesses reported crime")
	for role in ["Daroga","Burkundaz"]: police.get_node("ThanaStaff/"+role).set_meta("dead",false)
	var pickup:=preload("res://world/suryagarh/settlements/supply_pickup.gd").new()
	police.add_child(pickup)
	pickup.global_position=actor.global_position
	pickup.interact(actor)
	check(pickup.taken and coordinator.phase=="approach" and coordinator.reason=="theft","Real station pickup failed to trigger theft")
	if coordinator.phase!="idle":
		coordinator.officer.set_meta("dead",true)
		await physics_frame
		await physics_frame
		coordinator.officer.set_meta("dead",false)
		check(coordinator.phase=="idle","Officer loss failed safe abort")
	coordinator.cooldown=0
	actor.global_position=police.to_global(Vector3(7.2,.9,14.3))
	for frame in 3:await physics_frame
	check(not coordinator.report_crime(actor,"theft",actor.global_position),"Officer saw through the cell wall")
	actor.global_position=police.to_global(Vector3(-4,.9,8.7))
	for frame in 3:await physics_frame
	check(coordinator.report_crime(actor,"theft",actor.global_position),"Sikh officer failed to witness incident")
	check(coordinator.officer.get_meta("thana_role","")=="burkundaz","Nearest Sikh guard was not selected")
	coordinator.abort()
	var report: Dictionary={"passed":errors.is_empty(),"errors":errors,"phases":phases,"escort_distance_m":coordinator.escort_distance,"max_player_step_m":max_step,"officer_palm_error_m":max_contact,"renderer":RenderingServer.get_current_rendering_method()}
	FileAccess.open("res://docs/characters/arjun/arrest_sequence_validation%s.json"%("_metal" if captures else ""),FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("POLICE ARREST ","PASS" if errors.is_empty() else "FAIL"," ",JSON.stringify(report))
	world.queue_free()
	current_scene=null
	await process_frame
	await process_frame
	quit(0 if errors.is_empty() else 1)
