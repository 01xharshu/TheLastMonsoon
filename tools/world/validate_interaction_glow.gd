extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	print(("PASS " if value else "FAIL ")+label)
	if not value:failures.append(label)
func run() -> void:
	root.size=Vector2i(1280,720)
	var world:=Node3D.new();root.add_child(world);current_scene=world
	var clock: Node=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
	var actor: CharacterBody3D=load("res://player/player.tscn").instantiate();world.add_child(actor);actor.position=Vector3(0,.9,0)
	var floor:=StaticBody3D.new();world.add_child(floor)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(20,.2,20);shape.shape=box;shape.position.y=-.1;floor.add_child(shape)
	var ground:=MeshInstance3D.new();ground.mesh=BoxMesh.new();ground.mesh.size=box.size;ground.position.y=-.1;floor.add_child(ground)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-30,0);world.add_child(light)
	var chest: Interactable=load("res://interaction/treasure_chest.gd").new();world.add_child(chest);chest.position=Vector3(0,0,1.6)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(-2.5,2.2,4.5);camera.look_at(chest.position+Vector3.UP*.5);camera.make_current()
	for frame in 8:await physics_frame
	actor.set_physics_process(false);actor.first_person=false;actor.get_node("VisualRoot").rotation.y=0
	var overlay: Control=actor.get_node("UI/HUDRoot/InteractionOverlay")
	var glow: Node=overlay.get_node("FocusGlow")
	glow.set_physics_process(false);glow.clear()
	var body: MeshInstance3D=chest.get_node("ChestBase")
	var source:=body.mesh
	var old: Material=body.material_overlay
	if OS.get_environment("TLM_GLOW_REVIEW")!="":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TLM_GLOW_REVIEW")+"/before.png")
	actor._update_interaction();glow._physics_process(.016)
	check(overlay.target==chest and glow.target==chest,"actual look-at interaction target gains glow")
	check(body.material_overlay is ShaderMaterial and body.mesh==source,"glow preserves original mesh/source materials")
	var count: int=glow.entries.size();glow._physics_process(.016)
	check(glow.entries.size()==count,"stable focus does not stack highlight passes")
	if OS.get_environment("TLM_GLOW_REVIEW")!="":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TLM_GLOW_REVIEW")+"/after.png")
	if DisplayServer.get_name()!="headless":
		# Freeze gameplay; sample the real shader clock over its full sweep + quiet gap.
		var samples: Array[Image]=[]
		for index in 9:
			await create_timer(.35).timeout
			await RenderingServer.frame_post_draw
			var shot:=root.get_texture().get_image()
			samples.append(shot)
			if OS.get_environment("TLM_GLOW_REVIEW")!="":shot.save_png(OS.get_environment("TLM_GLOW_REVIEW")+"/shine_%d.png"%index)
		var min_brightness:=INF
		var max_brightness:=0.0
		# Camera looks directly at the fixed chest; its central front excludes the player/HUD.
		var point:=camera.unproject_position(chest.position+Vector3(0,.45,0))
		for sample in samples:
			var brightness:=0.0
			for y in range(int(point.y)-12,int(point.y)+12):
				for x in range(int(point.x)-12,int(point.x)+12):brightness+=sample.get_pixel(x,y).r
			min_brightness=minf(min_brightness,brightness);max_brightness=maxf(max_brightness,brightness)
		check(max_brightness-min_brightness>8.0,"native moving shine crosses object and returns to quiet material")
	actor.get_node("VisualRoot").rotation.y=PI;actor._update_interaction();glow._physics_process(.016)
	check(glow.target==null and body.material_overlay==old,"looking away restores prior overlay")
	var prior:=StandardMaterial3D.new();body.material_overlay=prior
	glow.set_focus(chest)
	check(body.material_overlay.next_pass==prior,"existing overlay is retained without mutating it")
	glow.clear();check(body.material_overlay==prior,"focus cleanup restores exact existing overlay")
	body.material_overlay=old
	actor.get_node("VisualRoot").rotation.y=0
	var wall:=StaticBody3D.new();world.add_child(wall);wall.position=Vector3(0,1.3,.8)
	var block:=CollisionShape3D.new();var cube:=BoxShape3D.new();cube.size=Vector3(3,3,.1);block.shape=cube;wall.add_child(block)
	for frame in 3:await physics_frame
	actor._update_interaction();glow._physics_process(.016)
	check(glow.target==null,"solid wall prevents focus glow")
	wall.queue_free();for frame in 3:await physics_frame
	actor._update_interaction();glow._physics_process(.016)
	actor.set_meta("map_open",true);glow._physics_process(.016)
	check(glow.target==null and body.material_overlay==old,"map/UI state removes world highlight")
	actor.set_meta("map_open",false)
	glow.set_focus(chest);chest.queue_free();await process_frame;glow._physics_process(.016)
	check(glow.entries.is_empty(),"deleted interactable clears safely")
	var proxy:=Interactable.new();proxy.name="Proxy";world.add_child(proxy)
	var prop:=MeshInstance3D.new();prop.name="ProxyVisual";prop.mesh=BoxMesh.new();world.add_child(prop)
	var unrelated:=MeshInstance3D.new();unrelated.mesh=BoxMesh.new();world.add_child(unrelated)
	proxy.highlight_root_path=NodePath("../ProxyVisual")
	glow.set_focus(proxy)
	check(prop.material_overlay is ShaderMaterial and unrelated.material_overlay==null,"proxy visual root highlights only its authored object")
	glow.clear();check(prop.material_overlay==null,"proxy focus restores sibling visual root safely")
	if OS.get_environment("TLM_GLOW_REVIEW")!="":
		print("GLOW REVIEW READY")
		var deadline:=Time.get_ticks_msec()+90000
		while Time.get_ticks_msec()<deadline and not FileAccess.file_exists(OS.get_environment("TLM_GLOW_REVIEW")+"/glow_done"):await process_frame
	print("INTERACTION GLOW ","PASS" if failures.is_empty() else "FAIL",failures)
	await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures.is_empty() else 1)
