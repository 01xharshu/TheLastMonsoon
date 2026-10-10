extends SceneTree
var failures:Array[String]=[]
var output:=OS.get_environment("TLM_WORKER_TEST_OUTPUT")
var camera:Camera3D
var pictures:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	if not ok:failures.append(label)
func run()->void:
	var world:=Node3D.new();root.add_child(world);current_scene=world
	world.add_child(load("res://world/suryagarh/generated/landscape.scn").instantiate())
	var clock:Node=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock);clock.current_hour=10;clock.clock_paused=true
	var fixture:Node=load("res://tools/world/hospital_work_fixture.gd").new();world.add_child(fixture)
	for frame in 3000:
		await process_frame
		if fixture.complete:break
	check(fixture.complete,"actual cantonment builder completed")
	var posts:Node=load("res://world/suryagarh/settlements/civic_resident_posts.gd").new();world.add_child(posts)
	var work:Node
	for frame in 600:
		await process_frame
		var porter:=posts.get_node_or_null("HospitalLinenPorter")
		if porter!=null:work=porter.get_node_or_null("LinenDelivery")
		if work!=null and work.goods.size()==3 and work.waypoints.size()==5:break
	check(work!=null and work.goods.size()==3,"worker and three physical consignments")
	if work==null:print("RESIDENT_GOODS_RESULT FAIL ",failures);quit(1);return
	work.set_physics_process(false)
	if not output.is_empty():
		root.get_node("SaveManager").apply_options()
		var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-50,-30,0);world.add_child(sun)
		var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.65;world.add_child(environment)
		camera=Camera3D.new();world.add_child(camera);camera.current=true;camera.fov=44
		await photograph(work,"stock")
		var samples:Array[float]=[];var previous:=Time.get_ticks_usec()
		for frame in 180:
			await process_frame
			var now:=Time.get_ticks_usec();var seconds:=float(now-previous)/1000000;previous=now
			work.tick(minf(seconds,.1));samples.append(seconds*1000)
		var backing:=root.get_texture().get_image().get_size()
		samples.sort();print("WORKER_NATIVE_BUDGET viewport=",root.size," backing=",backing," scale=",root.scaling_3d_scale," median_ms=",samples[samples.size()/2]," p95_ms=",samples[int((samples.size()-1)*.95)])
	var obstacle:=StaticBody3D.new();world.add_child(obstacle)
	var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1.2,1.8,.25);collision.shape=box;obstacle.add_child(collision)
	obstacle.global_position=work.actor.global_position+Vector3(0,.9,1.2)
	await physics_frame
	for frame in 40:work.tick(.05);await physics_frame
	var stopped:Vector3=work.actor.global_position
	for frame in 20:work.tick(.05);await physics_frame
	check(work.actor.global_position.distance_to(stopped)<.001 and work.delivered==0,"solid obstacle pauses work without transferring goods")
	obstacle.queue_free();await physics_frame;work.blocked=0
	var max_hand:=0.0;var saved:=false
	for frame in 3600:
		work.tick(.05);await physics_frame
		if not output.is_empty() and not pictures.has(work.phase) and work.phase in ["lift","inside","lower","return"] and (work.phase not in ["lift","lower"] or work.progress>.6):
			pictures[work.phase]=true;await photograph(work,work.phase)
		if work.hand_error>max_hand+.005:print("GOODS_CONTACT ",work.phase," ",work.progress," error=",work.hand_error)
		max_hand=maxf(max_hand,work.hand_error)
		if not saved and work.phase=="inside":
			var before:Vector3=work.actor.global_position;clock.current_hour=20;work.tick(.5)
			check(work.actor.global_position.distance_to(before)<.001 and work.goods[0].get_parent()==work.actor,"after-hours pause retains carried goods")
			clock.current_hour=10
			var state:Dictionary=JSON.parse_string(JSON.stringify(work.export_state()))
			work.restore_state(state);saved=true
			check(work.goods[0].get_parent()==work.actor,"save restores carried consignment")
		if work.phase=="rest":break
		if work.blocked>100:break
		if frame%600==0:print("GOODS_PROGRESS ",work.phase," ",work.actor.global_position," blocked=",work.blocked," grip=",max_hand)
	check(work.delivered==3 and work.phase=="rest","all three loads taken inside and worker returned")
	check(saved,"mid-carry JSON restore exercised")
	check(max_hand<.025,"palm targets within 25 mm")
	check(work.actor.body_collider.collision_layer==1,"worker body remains solid")
	for item:Node3D in work.goods:
		check(item.get_parent()==work.institution,"consignment retained inside hospital")
		check(item.get_node("ConsignmentBody").collision_layer==1,"stored goods remain solid to other people")
	if not output.is_empty():await photograph(work,"stored")
	print("RESIDENT_GOODS_RESULT ","PASS" if failures.is_empty() else "FAIL"," delivered=",work.delivered," blocked=",work.blocked," max_hand=",max_hand," failures=",failures)
	world.queue_free();await process_frame;root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)

func photograph(work:Node,label:String)->void:
	var focus:Vector3=work.institution.to_global(Vector3(.53,1.15,1.55)) if label=="stored" else work.actor.global_position+Vector3(0,.9,0)
	camera.global_position=focus+work.actor.global_basis*Vector3(2.1,.7,2.4);camera.look_at(focus)
	await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(output+"/worker_"+label+".png")
