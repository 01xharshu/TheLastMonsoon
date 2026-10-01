extends SceneTree
const NAMES = ["rest_corner","market_supply","armoury_supply"]
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.12,.14,.16)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.8,.84,.88)
	env.environment.ambient_light_energy = .7
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-65,-25,0)
	light.light_energy = 1.5
	stage.add_child(light)
	var floor_ := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(12,.02,6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.24,.27,.28)
	mesh.material = mat
	floor_.mesh = mesh
	floor_.position.y = -.01
	stage.add_child(floor_)
	var report := {"assets":[],"scope":"assembled candidates; support colliders checked; placement/gameplay and animation remain separate"}
	for i in NAMES.size():
		var prop: Node3D = load("res://objects/household/sets/"+NAMES[i]+".tscn").instantiate()
		prop.position.x = (i-1)*3.8
		stage.add_child(prop)
		assert(prop.get_node_or_null("Approach") != null)
		assert(prop.get_script() == null)
		if i == 0:
			assert(prop.get_node("Charpai").get_script().resource_path == "res://objects/charpai.gd")
		var bounds := AABB()
		var first := true
		var triangles := 0
		for part in prop.find_children("*","MeshInstance3D",true,false):
			if not part.is_visible_in_tree(): continue
			var box_: AABB = (prop.global_transform.affine_inverse() * part.global_transform) * part.get_aabb()
			bounds = box_ if first else bounds.merge(box_)
			first = false
			for s in part.mesh.get_surface_count():
				var arrays: Array = part.mesh.surface_get_arrays(s)
				var ids: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				triangles += ids.size()/3 if not ids.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()/3
		assert(bounds.position.y >= -.01 and bounds.size.length() > .1)
		report.assets.append({"name":NAMES[i],"size_m":str(bounds.size),"triangles":triangles,"bounds_and_approach":"PASS"})
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440,900)
		root.content_scale_size = root.size
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		var camera := Camera3D.new()
		stage.add_child(camera)
		camera.make_current()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 12.5
		camera.position = Vector3(3,6,8)
		camera.look_at(Vector3.ZERO)
		for frame in 12: await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/assets/activity_sets_b_overview.png")
		for i in NAMES.size():
			camera.size = 3.6
			var target := Vector3((i-1)*3.8,.4,0)
			camera.position = target+Vector3(1.6,2.2,2.8)
			camera.look_at(target)
			for frame in 8: await process_frame
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://docs/assets/activity_sets_b_"+NAMES[i]+".png")
	for frame in 3: await physics_frame
	for target in [Vector3(-3.8,.27,0),Vector3(0,.73,0),Vector3(3.8,.94,0)]:
		var hit := stage.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(target+Vector3.UP,target-Vector3.UP*.1))
		assert(not hit.is_empty(),"Primary set support collider missing")
	report["support_colliders"] = "PASS: charpai, counter and shelf"
	var suffix := "headless" if DisplayServer.get_name() == "headless" else "metal"
	var file := FileAccess.open("res://docs/assets/activity_sets_b_validation_"+suffix+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	stage.free()
	print("ACTIVITY SETS: floor bounds and grip markers PASS")
	quit()
