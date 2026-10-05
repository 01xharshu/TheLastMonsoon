extends SceneTree
func _initialize()->void:_run.call_deferred()
func _run()->void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	var world:=Node3D.new();root.add_child(world)
	var cow:Node3D=load("res://assets/animals/cow/household_cow.glb").instantiate();world.add_child(cow)
	preload("res://animals/cow_visual.gd").apply(cow)
	for mesh in cow.find_children("*","MeshInstance3D",true,false):
		for index in mesh.mesh.get_surface_count():
			var material=mesh.get_active_material(index)
			if material is StandardMaterial3D and "grey coat" in material.resource_name:print("COW COAT ",mesh.name," ",material.albedo_color," vertex ",material.vertex_color_use_as_albedo," shading ",material.shading_mode)
	var anim:=cow.find_child("AnimationPlayer",true,false) as AnimationPlayer
	print("COW CLIPS ",anim.get_animation_list())
	for clip in anim.get_animation_list():
		if "idle" in clip.to_lower():anim.get_animation(clip).loop_mode=Animation.LOOP_LINEAR;anim.play(clip)
	var sun:=DirectionalLight3D.new();world.add_child(sun);sun.rotation_degrees=Vector3(-45,-35,0);sun.shadow_enabled=true
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.42,.47,.48);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.8,.83,.82);env.environment.ambient_light_energy=.55;world.add_child(env)
	var ground:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(15,.1,15);ground.mesh=box;ground.position.y=-.05;world.add_child(ground)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.39,.31,.22);ground.material_override=mat
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current();camera.fov=45
	for view in [["side",Vector3(4,1.7,.1)],["quarter",Vector3(3,2,-3)],["front",Vector3(.1,1.3,-4)],["head",Vector3(1.05,1.4,-2.7)]]:
		camera.position=view[1];camera.look_at(Vector3(0,1.18,-1.36) if view[0]=="head" else Vector3(0,.85,-.2))
		for frame in 5:await process_frame
		if DisplayServer.get_name()!="headless":
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("res://docs/world/captures/cow_candidate_"+view[0]+".png")
	print("COW CANDIDATE NATIVE IMPORT: PASS; art/animation/contact review open")
	quit()
