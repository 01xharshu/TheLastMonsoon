extends SceneTree
## Native component pixels complement, but never replace, actual-world review.
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(960,540);root.content_scale_size=root.size
	var world := Node3D.new();root.add_child(world)
	var light := DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-30,0);world.add_child(light)
	var environment := WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.35,.43,.48)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(.65,.65,.65);environment.environment.ambient_light_energy=.6;world.add_child(environment)
	var wood := StandardMaterial3D.new();wood.albedo_color=Color(.23,.13,.07)
	var cloth := StandardMaterial3D.new();cloth.albedo_color=Color(.66,.54,.35)
	var village := Node3D.new();world.add_child(village)
	preload("res://world/suryagarh/route_and_market_detail.gd").canopy(village,cloth,0)
	for x in [-2.0,2.0]:
		for z in [-1.1,1.1]:piece(village,Vector3(x,1.25,z),Vector3(.14,2.5,.14),wood)
	var bazaar := Node3D.new();world.add_child(bazaar);bazaar.position.x=16
	var old := Node3D.new();old.name="ShadeRoof";bazaar.add_child(old)
	preload("res://world/suryagarh/route_and_market_detail.gd").bazaar_roof(bazaar)
	for x in [-4.0,4.0]:
		for z in [-3.4,3.4]:piece(bazaar,Vector3(x,1.69,z),Vector3(.18,3.08,.18),wood)
	var ground := StandardMaterial3D.new();ground.albedo_color=Color(.42,.37,.28)
	piece(world,Vector3(8,-.08,0),Vector3(32,.16,18),ground)
	var camera := Camera3D.new();world.add_child(camera);camera.make_current();camera.fov=65
	for view in [["cloth_component",Vector3(-4,1.8,4),Vector3(0,2.25,0)],["roof_component",Vector3(23,2.4,8),Vector3(16,3.1,0)],["roof_underside",Vector3(17,1.8,2.5),Vector3(16,3.1,0)]]:
		camera.global_position=view[1];camera.look_at(view[2])
		for frame in 12:await process_frame
		RenderingServer.force_draw()
		var output := OS.get_environment("TLM_TEST_OUTPUT_DIR")
		if not output.is_empty():assert(root.get_texture().get_image().save_png(output.path_join(view[0]+".png"))==OK)
		print("CONSTRUCTION VIEW ",view[0])
	world.queue_free();await process_frame
	print("NATIVE MARKET CONSTRUCTION PASS")
	quit()
func piece(parent: Node3D,at: Vector3,size: Vector3,material: Material) -> void:
	var mesh := MeshInstance3D.new();var box := BoxMesh.new();box.size=size;mesh.mesh=box;mesh.material_override=material;mesh.position=at;parent.add_child(mesh)
