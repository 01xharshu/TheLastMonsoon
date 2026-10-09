extends Node
## Real construction/MPFB fixture; --world also checks the integrated settlement.
const Variety=preload("res://world/suryagarh/settlements/village_household_variety.gd")
var failures: Array[String]=[]
var root: Window
var scene: Node3D
var builder: Node3D
var camera: Camera3D
var clock: Node
var output_dir := ""

class FixtureBuilder extends "res://world/suryagarh/settlements/settlement_builder.gd":
	func _ready() -> void:
		plaster=material(Color(.76,.70,.56));ochre=material(Color(.55,.40,.24));brick=material(Color(.44,.24,.16),true)
		wood=material(Color(.23,.13,.07));tile=material(Color(.43,.19,.105),true);stone=material(Color(.42,.40,.33),true);iron=material(Color(.13,.14,.13))

func _ready() -> void:
	root=get_tree().root
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output_dir=arg.trim_prefix("--output=")
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	if "--world" in OS.get_cmdline_user_args():
		scene=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
		root.add_child(scene);get_tree().current_scene=scene
		for i in 12:await get_tree().process_frame
		builder=scene.get_node("Settlement")
		clock=scene.get_node("GameTimeSystem")
	else:
		scene=Node3D.new();scene.name="VillageHouseholdFixture";root.add_child(scene);get_tree().current_scene=scene
		clock=GameTimeSystem.new();clock.name="GameTimeSystem";scene.add_child(clock)
		var bed: Node3D=load("res://objects/charpai.tscn").instantiate();bed.name="Charpai";scene.add_child(bed)
		builder=FixtureBuilder.new();builder.name="Settlement";scene.add_child(builder)
		await preload("res://world/suryagarh/settlements/bhairavpur_village.gd").new().build(builder)
		var environment := WorldEnvironment.new();var env := Environment.new()
		env.background_mode=Environment.BG_COLOR;env.background_color=Color(.35,.42,.48)
		env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color(.8,.8,.8);env.ambient_light_energy=.65
		environment.environment=env;scene.add_child(environment)
		var sun := DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-25,0);sun.shadow_enabled=true;scene.add_child(sun)
	clock.clock_paused=true
	camera=Camera3D.new();camera.fov=58;scene.add_child(camera);camera.make_current()
	for i in 4:await get_tree().physics_frame
	var homes:=get_tree().get_nodes_in_group("bhairavpur_home")
	check(homes.size()==33,"all original homes retained")
	var timber_count:=0;var fences:=0;var hearths:=0;var flues:=0
	for home: Node3D in homes:
		if home.get_meta("wall_construction","")=="timber":timber_count+=1
		if home.get_meta("boundary_construction","")=="wooden fence":
			fences+=1
			var extent: Vector3=home.get_node("Plinth").find_children("*","CollisionShape3D",true,false)[0].shape.size
			var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.32;capsule.height=1.7
			query.shape=capsule;query.transform=Transform3D(home.global_basis,home.to_global(Vector3(0,1.2,(extent.z-1)*.5+4.6)))
			query.collision_mask=1
			check(home.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),str(home.name)+" fence entrance fits a person")
		var fire:=home.get_node_or_null("HouseCookingFire")
		if fire==null:continue
		hearths+=1
		if home.get_meta("cooking_vent","")=="masonry flue":
			flues+=1
			var origin: Vector3=home.to_global(Vector3(0,2.2,fire.position.z))
			var ray:=PhysicsRayQueryParameters3D.create(origin,origin+Vector3.UP*3)
			check(home.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),str(home.name)+" chimney roof passage is open")
		else:
			var origin: Vector3=home.to_global(Vector3(0,1.9,fire.position.z))
			var ray:=PhysicsRayQueryParameters3D.create(origin,home.to_global(fire.smoke_outlet))
			var hit:=home.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty():print("VENT BLOCKER ",hit.collider.get_path()," at ",hit.position)
			check(hit.is_empty(),str(home.name)+" rear smoke outlet is open")
	check(timber_count==6 and fences==4 and hearths==8 and flues==2,"six timber homes, four fences, eight hearths, two flues")
	for hour in [7,12,18,22]:
		_set_hour(hour)
		for i in 4:await get_tree().process_frame
		for home: Node3D in homes:
			var fire:=home.get_node_or_null("HouseCookingFire")
			if fire!=null:check(fire.burning==(hour in [7,18]),str(home.name)+" cooking at "+str(hour))
	_set_hour(18)
	for i in (8 if "--world" in OS.get_cmdline_user_args() else 120):await get_tree().process_frame
	await _view("timber_fence",builder.get_node("BhairavpurHouse9"),Vector3(12,5,14),Vector3(0,1.8,2))
	await _view("window_smoke",builder.get_node("BhairavpurHouse9"),Vector3(8,4,-12),Vector3(0,2,-2))
	await _view("chimney_smoke",builder.get_node("BhairavpurHouse26"),Vector3(10,6,-12),Vector3(0,2.7,-1))
	if not "--world" in OS.get_cmdline_user_args():
		await _torch("male")
		await _torch("female")
	else:
		_set_hour(20)
		var start:=Time.get_ticks_msec()
		while get_tree().get_nodes_in_group("village_carried_light").size()<2 and Time.get_ticks_msec()-start<20000:await get_tree().process_frame
		var carriers:=get_tree().get_nodes_in_group("village_carried_light")
		check(carriers.size()==2,"two existing villagers receive night torches")
		for torch: Node3D in carriers:
			check(torch.actor.is_in_group("village_work_residents"),"carried light reuses existing resident")
			check(torch.visible and torch.hand_error<.003,"live gathering journey holds burning torch")
		if not carriers.is_empty():
			var origin: Vector3=carriers[0].actor.global_position
			var walking_start:=Time.get_ticks_msec()
			while Time.get_ticks_msec()-walking_start<5000:await get_tree().process_frame
			check(carriers[0].actor.global_position.distance_to(origin)>.2,"night torch carrier progresses at normal speed")
			await _view("world_carried_torch",carriers[0].actor,Vector3(-2,1.7,3.2),Vector3(0,1,0))
	print("VILLAGE HOUSEHOLD VARIETY ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	get_tree().current_scene=null
	scene.queue_free();await get_tree().process_frame;await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func _set_hour(hour: int) -> void:
	clock.total_game_minutes=float((clock.current_day-1)*1440+hour*60)
	clock._update_readable_time(true)

func _view(label: String, home: Node3D, offset: Vector3, target: Vector3) -> void:
	camera.global_position=home.to_global(offset);camera.look_at(home.to_global(target))
	for i in 12:await get_tree().process_frame
	if not output_dir.is_empty() and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output_dir.path_join(label+".png"))

func _torch(sex: String) -> void:
	var actor:=preload("res://characters/npcs/indian/indian_street_actor.gd").new()
	actor.name="ExistingMPFBResident_"+sex;actor.movement_enabled=false;actor.household_job="social"
	actor.movement_profile=&"female" if sex=="female" else &"male"
	actor.add_child(preload("res://characters/human_scene.gd").instantiate("res://characters/npcs/street_residents/"+("female_03" if sex=="female" else "male_02")+".glb",false))
	scene.add_child(actor);actor.set_process(false)
	_set_hour(20)
	for node in scene.get_children():
		if node is DirectionalLight3D:node.light_energy=.025
		if node is WorldEnvironment:
			node.environment.background_color=Color(.015,.02,.035)
			node.environment.ambient_light_energy=.12
	actor.position=Vector3(-321,7.2,220)
	actor.travel_speed=.8
	actor.foot_plant_enabled=false
	var torch:=preload("res://world/suryagarh/settlements/village_carried_torch.gd").new();torch.configure(actor)
	camera.global_position=actor.to_global(Vector3(-2,1.7,3.2));camera.look_at(actor.to_global(Vector3(0,1,0)))
	var audio:=get_tree().root.get_node("WorldAudio/EnvironmentAudio")
	check(audio.sources.has(torch.light.get_instance_id()),"torch registered with shared positional fire audio")
	var worst:=0.0
	var reach:=0.0
	var started:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-started<4500:
		await get_tree().process_frame
		var delta: float=scene.get_process_delta_time()
		actor._set_animation(&"walk",delta);torch.update(delta,true)
		worst=maxf(worst,torch.hand_error)
		reach=maxf(reach,torch.reach_error)
	print("TORCH REACH ERROR ",reach)
	check(worst<.003,"torch remains attached to walking palm")
	check(reach<.025,"walking arm reaches torch without stretching")
	if not output_dir.is_empty() and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output_dir.path_join("carried_torch_"+sex+".png"))
	actor.set_meta("dead",true);torch.update(.016,true)
	check(not torch.visible and not torch.smoke.emitting,"incapacitation stops carried flame/smoke")
	actor.queue_free()
	await get_tree().process_frame
