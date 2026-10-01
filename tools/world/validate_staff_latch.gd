extends SceneTree
var failures: Array[String]=[]
var stage: Node3D
var camera: Camera3D
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1280,720)
	stage=Node3D.new()
	root.add_child(stage)
	current_scene=stage
	var clock=preload("res://world/suryagarh/systems/game_time_system.gd").new()
	clock.name="GameTimeSystem"
	clock.clock_paused=true
	clock.current_hour=10
	stage.add_child(clock)
	var floor_body:=StaticBody3D.new()
	var floor_shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new(); box.size=Vector3(30,.2,30)
	floor_shape.shape=box; floor_shape.position.y=-.1
	floor_body.add_child(floor_shape);stage.add_child(floor_body)
	var floor_mesh:=MeshInstance3D.new()
	var floor_box:=BoxMesh.new();floor_box.size=box.size
	floor_mesh.mesh=floor_box;floor_mesh.position.y=-.1
	stage.add_child(floor_mesh)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-25,0);stage.add_child(light)
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.32,.35,.38)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.5
	stage.add_child(env)
	var door=preload("res://objects/hinged_door.gd").new()
	door.name="TestDoor";door.position=Vector3(-1.3,0,0);door.opened=false;door.night_lock=false;door.auto_open_at_dawn=false
	door.build(StandardMaterial3D.new());stage.add_child(door)
	var player=load("res://player/player.tscn").instantiate()
	stage.add_child(player);player.set_physics_process(false);player.set_process_unhandled_input(false)
	player.global_position=Vector3(.12,.9,1.8);player.get_node("VisualRoot").rotation.y=PI
	for layer in player.find_children("*","CanvasLayer",true,false):layer.hide()
	camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=48
	camera.position=Vector3(3,2.15,3.5);camera.look_at(Vector3(0,1.1,.3))
	for i in 4:await physics_frame
	check(player._find_interactable()==door,"normal E selects latch from approach distance")
	player._try_primary_interaction()
	var action=player.get_node_or_null("DoorLatchAction")
	check(action != null and action.phase != "","E starts authored latch action")
	var reached := false
	var gap := INF
	var early_motion := false
	for frame in 180:
		await physics_frame
		if action.phase=="reach" and action.elapsed<.32:early_motion=early_motion or door.moving
		if not reached and action.phase=="reach" and action.elapsed>=.34:
			reached=true;gap=action.last_gap
			await capture("arjun_door_latch_contact")
		if frame>40 and action.phase=="":break
	check(reached and gap<.04,"right palm reaches actual pull ring before release")
	check(not early_motion,"door remains still during approach and reach")
	await create_timer(1.3).timeout
	check(door.opened and is_equal_approx(door.swing,1.0),"contact releases and opens leaves away from player")
	check(not player.get_meta("door_latch_active",false),"recovery restores player control")
	await capture("arjun_door_latch_open")
	# Locked exterior must not start a gesture or open the door.
	door.restore_state(false);door.night_lock=true;door._time_changed(1,21,0)
	door.interact(player)
	check(action.phase=="" and not door.opened,"outside night latch rejects gesture")
	var kitchen:=Node3D.new();kitchen.name="FortKitchen";stage.add_child(kitchen)
	for side in ["L","R"]:
		var marker:=Marker3D.new();marker.name="CookContact"+side
		marker.position=Vector3(3.84,.83,.61) if side=="L" else Vector3(4.10,.88,.56)
		kitchen.add_child(marker)
	for index in 2:
		var actor=preload("res://characters/npcs/households/fort_staff.gd").new()
		actor.name="Cook" if index==0 else "Steward"
		actor.household_job=actor.name
		actor.movement_enabled=false;actor.position=Vector3(4+index*1.5,0,1);actor.rotation.y=PI
		var doc:=GLTFDocument.new();var state:=GLTFState.new()
		doc.append_from_file(ProjectSettings.globalize_path("res://WorkingAssets/NPCs/village_farmer/village_farmer_rigged_candidate.glb"),state)
		actor.add_child(doc.generate_scene(state));stage.add_child(actor)
		check(actor.get_meta("staff_cloth_surfaces",0)>=6,"role fabric overrides retain garment surfaces: "+actor.name)
		if index==0:
			var aprons=actor.find_children("CookSkinnedWorkApron","MeshInstance3D",true,false)
			check(aprons.size()==1 and aprons[0].skin != null,"cook apron uses original skeleton skin")
	for i in 30:await physics_frame
	camera.position=Vector3(4.8,1.6,-2.3);camera.look_at(Vector3(4.6,.85,1))
	await capture("fort_staff_clothing_detail")
	var report={"failures":failures,"passed":failures.is_empty(),"latch_contact_gap_m":gap,"renderer":DisplayServer.get_name(),"scope":"normal E approach/reach/release/recovery, night rejection, distinct staff fabric and skinned apron; art review separate"}
	var file=FileAccess.open("res://docs/world/staff_latch_validation.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	stage.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	for i in 4:await process_frame
	RenderingServer.force_draw(true)
	root.get_texture().get_image().save_png("res://docs/world/captures/"+label+".png")
