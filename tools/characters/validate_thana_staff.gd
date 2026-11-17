extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)
func run() -> void:
	var world: Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	var deadline:=Time.get_ticks_msec()+90000
	while (world.get_node_or_null("DevStory")==null or not world.get_node("DevStory").configured) and Time.get_ticks_msec()<deadline:
		await process_frame
	var station: Node3D=world.get_node("Settlement/DistrictPolice")
	var staff: Node3D=station.get_node("ThanaStaff")
	for role in ["Daroga","Mohurrir","Burkundaz"]:
		var officer: Node3D=staff.get_node(role)
		check(officer.get_meta("station_bound",false),"station staff retains identity "+role)
		check(officer._skeleton!=null and officer.body_collider!=null,"station staff retains rig and physical body "+role)
	var clerk: Node3D=staff.get_node("Mohurrir")
	var player: CharacterBody3D=world.get_node("Player")
	player.set_physics_process(false)
	player.global_position=station.to_global(Vector3(-7.2,.9,5.8))
	var opening: Node=world.get_node_or_null("OpeningSequence")
	if opening!=null:opening.skip_cinematic()
	player.get_node("UI/HUDRoot/MorningTutorial").restore_step(11)
	player.set_meta("document_busy",false)
	world.get_node("DevStory").set_process(false)
	var camera:=Camera3D.new()
	world.add_child(camera)
	camera.global_position=station.to_global(Vector3(-6.8,2.0,2.0))
	camera.look_at(clerk.global_position+Vector3.UP*.9)
	camera.make_current()
	clerk._process(.6)
	check(clerk.records_seated and clerk.records_pen.visible,"clerk sits with writing reed")
	var root_before:=clerk.global_position
	var hand_before: Vector3=clerk.palm_world("r")
	clerk._process(.35)
	check(clerk.palm_world("r").distance_to(hand_before)>.008,"writing hand moves over ledger")
	check(clerk.global_position.distance_to(root_before)<.001,"seated work retains grounded actor root")
	var ankle_index: int=clerk._skeleton.find_bone("foot_l")
	var ankle: Vector3=clerk._skeleton.to_global(clerk._skeleton.get_bone_global_pose(ankle_index).origin)
	check(absf(ankle.y-clerk.global_position.y-.1)<.04,"clerk feet reach floor")
	var page: Vector3=station.to_local(clerk.palm_world("r"))
	check(page.y>.88 and page.y<1.03 and absf(page.z-4.0)<.3,"writing palm stays over desktop")
	if DisplayServer.get_name()!="headless" and not OS.get_environment("TLM_GLOW_REVIEW").is_empty():
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(OS.get_environment("TLM_GLOW_REVIEW").path_join("station_clerk.png"))
	var defence: Node=clerk.get_node("SelfDefence")
	defence.alert(player)
	clerk._process(.05)
	check(not clerk.records_seated and not clerk.records_pen.visible,"clerk releases work when threatened")
	var body_shape: CollisionShape3D=clerk.body_collider.get_node("BodyShape")
	check(is_equal_approx(body_shape.shape.height,1.7),"clerk restores standing collision for defence")
	defence.finish(true)
	clerk._process(.5)
	check(clerk.records_seated,"clerk resumes record work after defence")
	var population: Node=world.get_node("CityRoutePopulation")
	for cart_index in [7,15]:
		var before: int=population.carts.size()
		population.spawn_record({"kind":"cart","route":"police_to_compound","index":cart_index,"count":4})
		check(population.carts.size()==before+1,"station road cart spawns through population owner")
		var cart: Node3D=population.carts[-1]
		var journey: Node=cart.get_node("CityRoadJourney")
		for endpoint: Vector2 in journey.route:
			check(endpoint.distance_to(Vector2(320,150))>27.0,"ambient cart turnaround stays clear of station coach frontage")
		cart.queue_free()
		population.carts.pop_back()
	check(population.set_saved_cart_priority("CityRoutePopulation/CityCart_police_to_compound"),"station cart retains saved identity")
	population.set_saved_cart_priority("")
	var crime: Node=world.get_node("CombatEncounters")
	crime.wanted=true
	crime.recruit_visible_police()
	check(not clerk.get_meta("police_engaged",false),"records clerk keeps station duty during patrol dispatch")
	print("THANA STAFF ", "PASS" if failures.is_empty() else "FAIL",failures)
	var output:=OS.get_environment("TLM_GLOW_REVIEW")
	if DisplayServer.get_name()!="headless" and not output.is_empty():
		var review_deadline:=Time.get_ticks_msec()+45000
		while Time.get_ticks_msec()<review_deadline and not FileAccess.file_exists(output.path_join("clerk_done")):
			await process_frame
	await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures.is_empty() else 1)
