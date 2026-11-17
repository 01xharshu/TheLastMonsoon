extends SceneTree
## Disposable real-terrain, real-worker prototype; not a world integration check.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	world.add_child(load("res://world/suryagarh/generated/landscape.scn").instantiate())
	var builder: Node3D = load("res://tools/world/opening_house_builder.gd").new()
	world.add_child(builder)
	var village = load("res://world/suryagarh/settlements/bhairavpur_village.gd").new()
	village.settlement = builder
	var store := Node3D.new()
	store.name = "BhairavpurGrainStore"
	builder.add_child(store)
	store.position = Vector3(-280,builder.layout.height(-280,285),285)
	village._piece(store,"StoreFloor",Vector3(0,.08,0),Vector3(7,.16,5),builder.wood)
	for x in [-2.2,0.0,2.2]:
		village._piece(store,"GrainBin",Vector3(x,.5,1.42),Vector3(1.6,.84,1.3),builder.wood)
	load("res://world/suryagarh/settlements/grain_storehouse_detail.gd").new().build(village,store)
	var counter: Node3D = load("res://objects/household/sets/market_supply.tscn").instantiate()
	counter.position = Vector3(2.45,.16,-1.65)
	store.add_child(counter)
	for side in [-1.0,1.0]:
		var fence: Node3D = load("res://objects/obstacles/timber_fence.tscn").instantiate()
		fence.position = Vector3(side*2,0,-4)
		store.add_child(fence)
	var gate: Node3D = load("res://objects/obstacles/timber_gate.tscn").instantiate()
	gate.position = Vector3(0,0,-4)
	store.add_child(gate)
	gate.get_node("HingePivot").rotation_degrees.y = -95
	var actor: Node3D = load("res://characters/npcs/indian/indian_street_actor.gd").new()
	actor.name = "GrainStorePorter"
	actor.movement_enabled = false
	actor.add_child(load("res://characters/human_scene.gd").instantiate("res://characters/npcs/street_residents/workman_03.glb",false))
	world.add_child(actor)
	actor.global_position = store.to_global(Vector3(0,0,-5))
	actor.global_position.y = builder.layout.height(actor.global_position.x,actor.global_position.z)
	var clock: Node = load("res://world/suryagarh/systems/game_time_system.gd").new()
	clock.name = "GameTimeSystem"
	world.add_child(clock)
	clock.current_hour = 10
	clock.clock_paused = true
	var work: Node = load("res://world/suryagarh/settlements/resident_goods_run.gd").new()
	work.name = "GrainSackDelivery"
	work.sack_delivery = true
	work.work_kind = "grain"
	work.actor = actor
	work.institution = store
	work.viewer = actor
	work.clock = clock
	work.cart_origin = Vector3(0,0,-10)
	work.store_base = Vector3(-1.05,1.00,-.85)
	work.stand_base = Vector3(-.55,0,-.85)
	work.route_points.assign([Vector3(-.5,0,-5.72),Vector3(0,0,-5),Vector3(0,0,-4),Vector3(0,0,-2.1),Vector3(-.55,0,-.85)])
	actor.add_child(work)
	for frame in 600:
		await process_frame
		if work.goods.size()==3 and work.waypoints.size()>=5: break
	if work.goods.size()!=3 or work.waypoints.size()<5:
		push_error("grain worker failed to prepare")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	work.set_physics_process(false)
	var review := OS.get_environment("TLM_GRAIN_REVIEW_DIR")
	var camera: Camera3D
	var captured: Dictionary = {}
	if review != "" and DisplayServer.get_name() != "headless":
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-48,-32,0)
		world.add_child(sun)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color(.8,.8,.8)
		environment.environment.ambient_light_energy = .6
		world.add_child(environment)
		camera = Camera3D.new()
		world.add_child(camera)
		camera.current = true
		camera.fov = 55
		camera.global_position = store.to_global(Vector3(8,4.7,-12))
		camera.look_at(store.to_global(Vector3(0,1.1,-3)))
		await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(review+"/store_overview.png")
	var peak_hand := 0.0
	var hand_by_phase: Dictionary = {}
	var worst: Dictionary = {}
	var saved_carry := false
	var restored_clean := true
	for frame in 5000:
		work.tick(.05)
		await physics_frame
		if not saved_carry and work.phase=="inside":
			var saved: Dictionary = JSON.parse_string(JSON.stringify(work.export_state()))
			work.restore_state(saved)
			saved_carry = true
			restored_clean = work.goods[0].get_parent()==actor
			for parcel in work.parcels:
				restored_clean = restored_clean and not parcel.visible and parcel.get_node("ConsignmentBody").collision_layer==0
		if work.hand_error > peak_hand and work.phase in ["lift","inside","lower"]:
			worst = {"phase":work.phase,"progress":work.progress,"actor":store.to_local(actor.global_position),"item":store.to_local(work.goods[work.delivered].global_position),"palm":store.to_local(actor.palm_world("l"))}
		peak_hand = maxf(peak_hand,work.hand_error)
		if work.phase in ["lift","inside","lower"]: hand_by_phase[work.phase] = maxf(float(hand_by_phase.get(work.phase,0.0)),work.hand_error)
		if frame%600==0: print("GRAIN_PROGRESS ",work.phase," at ",store.to_local(actor.global_position)," delivered ",work.delivered," blocked ",work.blocked," hand ",peak_hand)
		if camera != null and work.phase in ["lift","inside","lower"] and not captured.has(work.phase) and (work.phase=="inside" or work.progress>.5):
			captured[work.phase] = true
			camera.global_position = actor.global_position+Vector3(-2.6,1.8,2.8)
			camera.look_at(actor.global_position+Vector3.UP*.85)
			await process_frame
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png(review+"/"+work.phase+".png")
		if work.phase=="rest" and work.delivered==3:break
	var passed: bool = work.delivered==3 and work.phase=="rest" and peak_hand < .05 and saved_carry and restored_clean
	print("GRAIN_DELIVERY: ","PASS" if passed else "FAIL"," delivered=",work.delivered," phase=",work.phase," blocked=",work.blocked," hand=",peak_hand," by_phase=",hand_by_phase," worst=",worst," saved=",saved_carry," restore_clean=",restored_clean)
	preload("res://tools/test_audio_cleanup.gd").finish(self,0 if passed else 1)
