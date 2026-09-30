extends SceneTree
var failed := false
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
func run() -> void:
	var world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_physics_process(false)
	var actor = world.get_node("Player")
	var visual = actor.get_node("VisualRoot/CharacterVisual")
	var rifle = actor.get_node("RifleCombat")
	rifle.set_process(false)
	actor.position = Vector3(-230,50,180)
	actor.rotation = Vector3.ZERO
	actor.is_swimming = false
	var camera: Camera3D = rifle.camera
	camera.get_parent().rotation = Vector3.ZERO
	actor.get_node("CameraPivot").rotation = Vector3.ZERO
	var target := StaticBody3D.new()
	world.add_child(target)
	target.position = actor.position+Vector3(0,1,-10)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8,8,.3)
	collision.shape = shape
	target.add_child(collision)
	var target_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	target_mesh.mesh = box
	target.add_child(target_mesh)
	for i in 5: await physics_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	visual.equipment.selected = 1
	visual.equipment.stowed = false
	visual.equipment._refresh()
	visual.equipment.aiming = true
	visual.equipment.aim_direction = -camera.global_basis.z
	for i in 30: visual._process(1.0/60)
	rifle.aiming = true
	rifle.fire()
	check(rifle.shots_fired==1 and not rifle.loaded,"First shot must consume the chamber")
	check(rifle.impacts.size()==1,"Shot must leave one surface mark")
	check(rifle.sound.stream==rifle.SHOT,"Gunshot audio must be triggered")
	if DisplayServer.get_name() != "headless" and rifle.impacts.size()>0:
		var impact: Node3D = rifle.impacts[0]
		var review_camera := Camera3D.new()
		world.add_child(review_camera)
		review_camera.position = impact.global_position+Vector3(0,1,2.4)
		review_camera.look_at(impact.global_position)
		review_camera.make_current()
		actor.get_node("UI").hide()
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/realism_rifle_impact.png")
		review_camera.queue_free()
		camera.make_current()
		actor.get_node("UI").show()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	rifle.fire()
	check(rifle.shots_fired==1,"Empty rifle fired twice")
	actor.inventory.add_item("paper_cartridges",2)
	rifle.start_reload()
	check(is_equal_approx(rifle.reload_remaining,rifle.RELOAD_SECONDS),"Reload did not use shared pacing duration")
	rifle.reload_remaining = rifle.RELOAD_SECONDS*0.88
	visual._process(1.0/60.0)
	var early_left: Vector3 = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_l")).origin
	rifle.reload_remaining = rifle.RELOAD_SECONDS*0.68
	visual._process(1.0/60.0)
	check(visual.equipment.enfield_cartridge.visible,"Enfield paper cartridge was absent at the loading hand")
	var cartridge_palm: Vector3 = visual.skeleton.global_transform * (visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_l")) * visual.equipment.palm_offsets["l"])
	check(visual.equipment.enfield_cartridge.global_position.distance_to(cartridge_palm) < 0.10,"Enfield cartridge was not in the left palm")
	rifle.reload_remaining = rifle.RELOAD_SECONDS*0.36
	visual._process(1.0/60.0)
	check(not visual.equipment.enfield_cartridge.visible,"Enfield paper cartridge remained after the loading gesture")
	var loading_palm: Vector3 = visual.skeleton.global_transform * (visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_l")) * visual.equipment.palm_offsets["l"])
	var loading_contact: Vector3 = visual.equipment.enfield_hand.to_local(loading_palm)
	check(loading_contact.x > 1.08 or Vector2(loading_contact.y-0.057, loading_contact.z).length() > 0.035,"Enfield loading palm entered the barrel/fore-end")
	var loading_left: Vector3 = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_l")).origin
	check(early_left.distance_to(loading_left) > 0.06,"Enfield loading hand did not move")
	check(visual.equipment.reload_progress > 0.5,"Enfield reload pose did not follow timer")
	var rod: Node3D = visual.equipment.enfield_hand.find_child("enfield_ramrod",true,false)
	check(rod != null and rod.position.x > (visual.equipment.ramrod_rest["enfield_ramrod"] as Transform3D).origin.x + 0.1,"Enfield ramrod did not extend")
	var sample_count := int(rifle.RELOAD_SECONDS*60.0)
	var max_pinch_error := 0.0
	var previous_contact := Vector3.ZERO
	var maximum_step := 0.0
	for sample in sample_count+1:
		rifle.reload_remaining = maxf(0.001,rifle.RELOAD_SECONDS*(1.0-float(sample)/sample_count))
		visual._process(1.0/60.0)
		var rig: Skeleton3D = visual.skeleton
		var pinch := rig.to_global((rig.get_bone_global_pose(rig.find_bone("index_03_l")).origin+rig.get_bone_global_pose(rig.find_bone("thumb_03_l")).origin)*0.5)
		var loading: Dictionary = preload("res://player/enfield_loading_sequence.gd").state(visual.equipment.reload_progress)
		if sample > 0 and previous_contact.distance_to(loading.contact) > maximum_step:
			maximum_step = previous_contact.distance_to(loading.contact)
		previous_contact = loading.contact
		if (visual.equipment.reload_progress >= 0.52 and visual.equipment.reload_progress < 0.58) or (visual.equipment.reload_progress >= 0.91 and visual.equipment.reload_progress < 0.96):
			var head := rig.to_global(rig.get_bone_global_pose(rig.find_bone("head")).origin)
			var motion: Transform3D = loading.rod
			var tip_a: Vector3 = visual.equipment.enfield_hand.to_global(motion*Vector3(0.08,-0.003,0))
			var tip_b: Vector3 = visual.equipment.enfield_hand.to_global(motion*Vector3(1.04,-0.003,0))
			check(head.distance_to(Geometry3D.get_closest_point_to_segment(head,tip_a,tip_b)) > 0.16,"Ramrod turn entered head envelope")
		if visual.equipment.enfield_cartridge.visible:
			check(visual.equipment.enfield_cartridge.global_basis.y.dot(visual.equipment.enfield_hand.global_basis.x.normalized()) > 0.999,"Cartridge axis missed bore")
		max_pinch_error = maxf(max_pinch_error,pinch.distance_to(visual.equipment.enfield_hand.to_global(loading.contact)))
	check(max_pinch_error < 0.005,"Loading fingers lost cartridge/ramrod contact: " + str(max_pinch_error))
	for boundary in [0.10,0.26,0.34,0.36,0.395,0.42,0.45,0.48,0.52,0.58,0.63,0.65,0.70,0.72,0.76,0.80,0.82,0.86,0.88,0.91,0.96]:
		var before: Dictionary = preload("res://player/enfield_loading_sequence.gd").state(boundary-0.00001)
		var after: Dictionary = preload("res://player/enfield_loading_sequence.gd").state(boundary+0.00001)
		check((before.contact as Vector3).distance_to(after.contact) < 0.001,"Loading contact jumps at phase " + str(boundary))
		check((before.rod as Transform3D).origin.distance_to((after.rod as Transform3D).origin) < 0.001,"Ramrod jumps at phase " + str(boundary))
	check(maximum_step*visual.equipment.ENFIELD_SCALE < 0.06,"Reload movement still exceeds 60 mm per 60 fps frame")
	print("RELOAD PATH MAX STEP: ",maximum_step," source m")
	print("RELOAD CONTACT SWEEP: ",max_pinch_error," m / ",sample_count+1," poses")
	rifle.reload_remaining = rifle.RELOAD_SECONDS
	rifle._process(5.0)
	check(not rifle.loaded and is_equal_approx(rifle.reload_remaining,rifle.RELOAD_SECONDS-5.0),"Slower reload completed at the old five-second deadline")
	rifle._process(rifle.RELOAD_SECONDS-5.0+0.1)
	check(rifle.loaded,"Reload did not chamber a round")
	visual._process(1.0/60.0)
	check(absf(rod.position.x - (visual.equipment.ramrod_rest["enfield_ramrod"] as Transform3D).origin.x) < 0.001,"Enfield ramrod did not return")
	actor.set_meta("map_open",true)
	rifle.aiming = true
	rifle.fire()
	check(rifle.shots_fired==1,"Map allowed firing")
	actor.set_meta("map_open",false)
	# Obstacle immediately in front of muzzle must catch the shot before the target.
	var muzzle: Vector3 = visual.equipment.enfield_hand.to_global(rifle.MUZZLE)
	var cover := StaticBody3D.new()
	world.add_child(cover)
	cover.position = muzzle+Vector3(0,0,-.4)
	var cover_shape := CollisionShape3D.new()
	var cover_box := BoxShape3D.new()
	cover_box.size = Vector3(3,3,.15)
	cover_shape.shape = cover_box
	cover.add_child(cover_shape)
	for i in 3: await physics_frame
	rifle.aiming = true
	rifle.fire()
	check(rifle.impacts.size()==2,"Cover shot missing mark")
	if rifle.impacts.size()==2: check(rifle.impacts[1].get_parent()==cover,"Shot passed through muzzle cover")
	var pistol = actor.get_node("PistolCombat")
	pistol.set_process(false)
	actor.inventory.add_item("pistol",1)
	visual.equipment.selected = 3
	visual.equipment.stowed = false
	visual.equipment._refresh()
	visual.equipment.aiming = true
	visual.equipment.aim_direction = -camera.global_basis.z
	for i in 15: visual._process(1.0/60)
	pistol.aiming = true
	var before_marks: int = rifle.impacts.size()
	check(pistol.fire(),"Pistol did not fire")
	check(pistol.rounds==4 and pistol.shots_fired==1,"Pistol chamber did not advance")
	check(pistol.shot_sound.stream==pistol.SHOT and pistol.shot_sound.playing,"Pistol sound did not start")
	check(rifle.impacts.size()==before_marks+1,"Pistol left no impact mark")
	for i in 4: pistol.fire()
	check(pistol.rounds==0 and not pistol.fire(),"Pistol fired beyond five chambers")
	check(not pistol.start_reload(),"Pistol reloaded without ammunition")
	actor.inventory.add_item("pistol_ball",5)
	check(pistol.start_reload(),"Pistol reload did not start")
	pistol.reload_remaining = 3.4
	visual._process(1.0/60.0)
	var pistol_early: Vector3 = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_l")).origin
	pistol.reload_remaining = 1.5
	visual._process(1.0/60.0)
	var pistol_loading: Vector3 = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_l")).origin
	check(pistol_early.distance_to(pistol_loading) > 0.04,"Pistol loading hand did not move")
	pistol._process(4.0)
	check(pistol.rounds==5 and actor.inventory.get_item_count("pistol_ball")==0,"Pistol ammunition was not consumed")
	print("FIREARMS TEST ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
