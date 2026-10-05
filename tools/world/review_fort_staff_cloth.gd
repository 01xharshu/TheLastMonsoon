extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	var stage:=Node3D.new();root.add_child(stage);current_scene=stage
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.3,.32,.34)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;stage.add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-25,0);stage.add_child(light)
	var kitchen:=Node3D.new();kitchen.name="FortKitchen";stage.add_child(kitchen)
	for side in ["L","R"]:
		var marker:=Marker3D.new();marker.name="CookContact"+side
		marker.position=Vector3(3.84,.86,.61) if side=="L" else Vector3(4.10,.88,.56);kitchen.add_child(marker)
	var actor=preload("res://characters/npcs/households/fort_staff.gd").new()
	actor.name="Cook";actor.household_job="Cook";actor.movement_enabled=false;actor.position=Vector3(4,0,1);actor.rotation.y=PI
	var doc:=GLTFDocument.new();var state:=GLTFState.new()
	doc.append_from_file(ProjectSettings.globalize_path("res://WorkingAssets/NPCs/fort_staff/fort_staff_rigged_candidate.glb"),state)
	actor.add_child(doc.generate_scene(state));stage.add_child(actor)
	var camera:=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=38
	camera.position=Vector3(4.1,1.2,-1.8);camera.look_at(Vector3(4,.85,1))
	for i in 20:await process_frame
	actor.set_process(false)
	await capture("res://docs/world/captures/fort_cook_cloth_front.png")
	camera.position=Vector3(1.6,1.1,1.1);camera.look_at(Vector3(4,.9,1))
	await capture("res://docs/world/captures/fort_cook_cloth_side.png")
	for node: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if "upper_cutout" in node.name:
			var rig: Skeleton3D=node.get_node(node.skeleton)
			for bind in node.skin.get_bind_count():
				print("BIND ",bind," ",node.skin.get_bind_name(bind)," ",node.skin.get_bind_bone(bind)," ",node.skin.get_bind_pose(bind))
			var a=node.mesh.surface_get_arrays(0)
			var printed:=0
			for i in a[Mesh.ARRAY_VERTEX].size():
				var v: Vector3=a[Mesh.ARRAY_VERTEX][i]
				if v.y>.96 and v.y<1.01 and absf(v.x)<.15 and printed<6:
					printed+=1;print("WAIST ",v," ",Array(a[Mesh.ARRAY_BONES]).slice(i*4,i*4+4)," ",Array(a[Mesh.ARRAY_WEIGHTS]).slice(i*4,i*4+4))
		if node.name != "CookSkinnedWorkApron":node.hide()
	await capture("/tmp/tlm_apron_isolated.png")
	quit()
func capture(path: String) -> void:
	for i in 3:await process_frame
	RenderingServer.force_draw(true)
	root.get_texture().get_image().save_png(path)
