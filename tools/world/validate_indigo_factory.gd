extends SceneTree
## Actual New Journey/Continue site, geometry, actors and persistent batch ledger.
const Data=preload("res://world/suryagarh/settlements/indigo_factory_data.gd")
class FactoryViewer extends CharacterBody3D:
	var health:=100.0

var failures:Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
	if not ok:failures.append(label);push_error(label)
func run() -> void:
	if OS.get_environment("TLM_FACTORY_ARCHITECTURE")=="1":
		await architecture_review();return
	var saves:Node=root.get_node("SaveManager")
	saves.options.graphics_quality=1
	var loader:=preload("res://ui/journey_loading.gd").new();root.add_child(loader)
	check(await loader.begin(0),"New Journey loads the production world")
	if not failures.is_empty():saves.quit_game(1);return
	var world:Node3D=current_scene;var factory:Node=world.get_node("IndigoFactory")
	check(factory.configured,"factory startup completes before world reveal")
	if not factory.configured:saves.quit_game(1);return
	var operations:Node=factory.operations
	check(operations.configured and operations.workers.size()==3,"three existing MPFB worker instances")
	check(operations.is_in_group("institution_operations"),"existing save participant registration")
	var map:Node=world.get_node("Player/UI/WorldMap");map.refresh_sites()
	check(map.sites.has("Indigo Processing Factory"),"actual site appears on shared map")
	for worker:Node3D in operations.workers:
		check(worker.animation_tree!=null and worker.get("_skeleton")!=null,"worker rig and AnimationTree retained")
		check(worker.get_meta("population_expansion_exempt",false),"factory identities cannot be doubled")
	var actor:CharacterBody3D=world.get_node("Player")
	var opening:Node=world.get_node("OpeningSequence")
	var skip:=InputEventKey.new();skip.keycode=KEY_ESCAPE;skip.pressed=true
	opening._input(skip);await process_frame;opening._input(skip)
	var deadline:=Time.get_ticks_msec()+90000
	while opening.state!="done" and Time.get_ticks_msec()<deadline:await process_frame
	check(opening.state=="done","ordinary opening skip releases controls")
	var clock:Node=world.get_node("GameTimeSystem");clock.total_game_minutes=600;clock.clock_paused=true;clock._update_readable_time(true)
	operations.restore_state({})
	operations.advance(30)
	check(operations.phase=="steeping" and operations.raw_bundles==20,"receiving consumes four actual bundles once")
	operations.advance(240)
	check(operations.phase=="beating","steeping feeds lower beating vats")
	operations.advance(480+60+60)
	check(operations.phase=="drying","beating settling and pressing precede drying")
	operations.advance(4320+60)
	check(operations.finished_crates==1 and operations.batches==1,"one completed cycle produces exactly one crate")
	var saved:Dictionary=operations.export_state()
	operations.restore_state(saved);operations.restore_state(saved)
	check(operations.finished_crates==1 and operations.raw_bundles==20,"repeated restore does not produce stock")
	operations.restore_state({"phase":"beating","phase_minutes":0})
	operations.advance_calendar(17*60,31*60)
	check(operations.phase=="beating" and is_equal_approx(operations.phase_minutes,120.0),"rest jump counts two staffed hours and excludes the night")
	operations.restore_state({"phase":"steeping","phase_minutes":230})
	operations.advance_calendar(19*60,20*60)
	check(operations.phase=="beating" and operations.phase_minutes==0,"overnight chemistry stops when manual beating is reached")
	operations.restore_state({"raw_bundles":0})
	operations.advance_calendar(600,600+1440*70)
	check(operations.finished_crates==0 and operations.raw_bundles==0,"exhausted stock never creates an extra batch")
	var injured:Node3D=operations.workers[0]
	var healthy:Dictionary=injured.export_state()
	injured.restore_state({"health":0,"dead":true});injured.restore_state({"health":0,"dead":true})
	check(injured.get_node("Vitality").dead and injured.get_node("CombatMotion").state=="down","restored dead worker remains inactive without death replay")
	injured.restore_state(healthy)
	check(not injured.get_node("Vitality").dead and injured.get_node("CombatMotion").state=="","healthy restore clears obsolete down pose")
	operations.restore_state(saved)
	check(not operations.request("accounts",actor),"remote inspection rejected")
	actor.set_meta("opening_active",false)
	actor.global_position=factory.stations.accounts.global_position
	if actor.has_node("PlayerSafety"):actor.get_node("PlayerSafety").peak=-INF
	check(operations.request("accounts",actor) and operations.record_read,"account inspection uses existing interaction/message path")
	operations.phase="beating";operations.phase_minutes=0;operations.update_liquor()
	actor.global_position=factory.point(Vector2(-12,0))+Vector3.UP
	if actor.has_node("PlayerSafety"):actor.get_node("PlayerSafety").peak=-INF
	for frame in 180:await physics_frame
	var carrier:Node3D=operations.workers[1]
	check(carrier.travelled>.5,"carrier makes physically swept progress")
	var beater:Node3D=operations.workers[0]
	check(float(beater.get_meta("hand_contact_l",1.0))<.08 and float(beater.get_meta("hand_contact_r",1.0))<.08,"paddle grips stay within eight centimetres")
	operations.phase="pressing";operations.update_liquor()
	for frame in 30:await physics_frame
	var presser:Node3D=operations.workers[2]
	check(float(presser.get_meta("hand_contact_l",1.0))<.08 and float(presser.get_meta("hand_contact_r",1.0))<.08,"press grips stay within eight centimetres")
	# A vertical support ray in each doorway proves ramps/floors survived batching.
	for label in ["DryingHouse","PackingStore","AccountOffice"]:
		var room:Node3D=factory.get_node("FactoryArchitecture/"+label)
		var at:=room.to_global(Vector3.ZERO)
		var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.4,at-Vector3.UP*.4,1<<30)
		check(not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),label+" has physical support after visual merge")
	# Use ordinary movement to enter the drying house over its real north ramp.
	var dry:Node3D=factory.get_node("FactoryArchitecture/DryingHouse")
	var start:=dry.to_global(Vector3(0,0,-12.5))
	var ramp_middle:=dry.to_global(Vector3(0,-.6,-10.5))
	var ramp_query:=PhysicsRayQueryParameters3D.create(ramp_middle+Vector3.UP*3,ramp_middle-Vector3.UP*3,1<<30)
	var ramp_hit:=world.get_world_3d().direct_space_state.intersect_ray(ramp_query)
	check(not ramp_hit.is_empty() and ramp_hit.normal.y>.7,"entrance ramp has upward-facing physical support")
	start.y=factory.height_at(Vector2(start.x,start.z))+1.02
	actor.global_position=start;actor.velocity=Vector3.ZERO
	actor.get_node("CameraPivot").global_rotation.y=PI
	if actor.has_node("PlayerSafety"):actor.get_node("PlayerSafety").peak=-INF
	for frame in 5:await physics_frame
	Input.action_press("move_forward")
	for frame in 180:await physics_frame
	Input.action_release("move_forward")
	var entry:=dry.to_local(actor.global_position)
	var next_query:=PhysicsShapeQueryParameters3D.new();next_query.shape=actor.get_node("CollisionShape3D").shape
	next_query.transform=actor.get_node("CollisionShape3D").global_transform;next_query.transform.origin+=Vector3(0,0,.12)
	next_query.exclude=[actor.get_rid()];next_query.collision_mask=1
	var obstacles:Array[String]=[]
	for hit in world.get_world_3d().direct_space_state.intersect_shape(next_query,8):obstacles.append(str(hit.collider.get_path()))
	check(entry.z> -5.7,"Arjun walks through drying doorway | local="+str(entry)+" from="+str(start)+" obstacles="+str(obstacles)+" physics="+str(actor.is_physics_processing())+" opening="+str(actor.get_meta("opening_active",false)))
	var before:Dictionary=operations.export_state()
	check(saves.save_game(world,3),"factory participates in ordinary SaveManager slot")
	var written:Dictionary=saves.read_slot(3)
	check(written.get("institution_operations",{}).has("IndigoFactory/Operations"),"save includes factory's stable owner path")
	operations.finished_crates=99
	saves.pending_slot=3;saves.apply_pending(world)
	await process_frame
	check(operations.finished_crates==before.finished_crates and operations.record_read,"ordinary save restore recovers stock and inspection")
	if OS.get_environment("TLM_FACTORY_CONTINUE")=="1":
		var next:=preload("res://ui/journey_loading.gd").new();root.add_child(next)
		check(await next.begin(3),"Continue reconstructs factory through real loader")
		factory=current_scene.get_node("IndigoFactory");operations=factory.operations
		check(operations.finished_crates==before.finished_crates and operations.record_read,"fresh Continue restores factory ledger")
	if DisplayServer.get_name()!="headless":await review(factory)
	print("INDIGO FACTORY ","PASS" if failures.is_empty() else "FAIL"," | ",failures)
	saves.quit_game(0 if failures.is_empty() else 1)

func review(factory:Node3D) -> void:
	root.size=Vector2i(1280,720)
	for _frame in 5:await process_frame
	root.get_node("SaveManager")._update_render_budget()
	var world:Node3D=current_scene
	var clock:Node=world.get_node("GameTimeSystem");clock.total_game_minutes=600;clock._update_readable_time(true)
	var actor:CharacterBody3D=world.get_node("Player")
	actor.global_position=factory.point(Vector2(-12,0))+Vector3.UP
	if actor.has_node("PlayerSafety"):actor.get_node("PlayerSafety").peak=-INF
	actor.set_physics_process(false)
	var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.far=1800
	var directory:=OS.get_environment("TLM_FACTORY_IMAGES")
	if directory.is_empty():return
	check(root.size==Vector2i(1280,720) and is_equal_approx(root.scaling_3d_scale,1.0),"native review uses actual Medium 1280x720 render budget")
	var frames:Array[float]=[]
	for spec in [["overview",Vector3(-47,30,-48),Vector3(0,10,0),"beating"],["vats",Vector3(-1,15,-31),Vector3(12,12,-14),"beating"],["drying",Vector3(19,14,26),Vector3(19,13,13),"drying"],["press",Vector3(23,14,6),Vector3(16,12,1),"pressing"]]:
		factory.operations.phase=spec[3];factory.operations.update_liquor()
		camera.global_position=Vector3(factory.Data.CENTER.x,0,factory.Data.CENTER.y)+spec[1]
		camera.look_at(Vector3(factory.Data.CENTER.x,0,factory.Data.CENTER.y)+spec[2])
		for i in 12:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory.path_join(spec[0]+".png"))
		if spec[0]=="press":
			var worker:Node3D=factory.operations.workers[2]
			print("FACTORY NATIVE press_grip_l=",worker.get_meta("hand_contact_l",INF)," r=",worker.get_meta("hand_contact_r",INF))
	for i in 120:
		var started:=Time.get_ticks_usec();await process_frame;frames.append((Time.get_ticks_usec()-started)/1000.0)
	frames.sort()
	print("FACTORY NATIVE frames120 median_ms=",frames[60]," p95_ms=",frames[114]," window=",root.size," texture_metadata=",root.get_texture().get_size()," scale=",root.scaling_3d_scale," whole world; no isolated attribution")

func architecture_review() -> void:
	# Bounded construction fixture, explicitly separate from the real journey gate.
	root.size=Vector2i(1280,720)
	var world:=Node3D.new();root.add_child(world);current_scene=world
	var clock:=preload("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock);clock.clock_paused=true
	var viewer:=FactoryViewer.new();viewer.name="Player";world.add_child(viewer)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-50,-35,0);sun.shadow_enabled=true;world.add_child(sun)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.65,.70,.73);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(.75,.78,.82);environment.environment.ambient_light_energy=.65;world.add_child(environment)
	var factory:=preload("res://world/suryagarh/settlements/indigo_factory.gd").new();world.add_child(factory)
	while not factory.configured:await process_frame
	var faces:Array[Vector3]=[]
	for x in range(-90,90,3):
		for z in range(-90,90,3):
			var a:Vector3=factory.point(Vector2(x,z));var b:Vector3=factory.point(Vector2(x+3,z))
			var c:Vector3=factory.point(Vector2(x,z+3));var d:Vector3=factory.point(Vector2(x+3,z+3))
			faces.append_array([a,b,c,b,d,c])
	factory.surface(world,"FixtureTerrain",faces,factory.materials.earth,true)
	if DisplayServer.get_name()!="headless":await review(factory)
	print("INDIGO FACTORY ARCHITECTURE ","PASS" if failures.is_empty() else "FAIL"," | ",failures)
	root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
