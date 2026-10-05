extends SceneTree
const TOOLS = ["wooden_mallet","wood_chisel","wood_hand_plane","weaving_shuttle","yarn_spool"]
const SETS = ["carpenter_work_surface","weaver_work_surface"]
func _initialize() -> void: run.call_deferred()
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
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(6,.02,6)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(.24,.27,.28)
	floor_mesh.material = floor_material
	floor_.mesh = floor_mesh
	floor_.position = Vector3(0,-.01,1)
	stage.add_child(floor_)
	var report := {"assets":[],"scope":"candidate geometry/support; no craft gameplay or human contact approval"}
	var props: Array[Node3D] = []
	for i in 7:
		var tool_: bool = i<5
		var label: String = TOOLS[i] if tool_ else SETS[i-5]
		var path := "res://objects/household/"+("craft/" if tool_ else "sets/")+label+".tscn"
		var prop: Node3D = load(path).instantiate()
		prop.position = Vector3((i-2)*.48,0,0) if tool_ else Vector3((i-5.5)*1.8,0,2.2)
		stage.add_child(prop)
		props.append(prop)
		assert(prop.get_node_or_null("Grip" if tool_ else "Approach") != null)
		assert(prop.get_script() == null)
		var bounds := AABB()
		var first := true
		var triangles := 0
		for mesh in prop.find_children("*","MeshInstance3D",true,false):
			var box_: AABB = (prop.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
			bounds = box_ if first else bounds.merge(box_)
			first = false
			for s in mesh.mesh.get_surface_count():
				var arrays: Array = mesh.mesh.surface_get_arrays(s)
				var ids: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				triangles += ids.size()/3 if not ids.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()/3
		assert(bounds.position.y>=-.001 and bounds.size.length()>.10)
		report.assets.append({"scene":path,"size_m":str(bounds.size),"triangles":triangles,"bounds_markers":"PASS"})
	for frame in 3: await physics_frame
	for i in [5,6]:
		var origin := props[i].global_position+Vector3(0,1.2,0)
		var hit := stage.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin-Vector3.UP*.6))
		assert(not hit.is_empty() and absf(hit.position.y-.78)<.001)
		var capsule := CapsuleShape3D.new()
		capsule.height = 1.7
		capsule.radius = .3
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform.origin = props[i].get_node("Approach").global_position+Vector3.UP*.94
		assert(stage.get_world_3d().direct_space_state.intersect_shape(query).is_empty())
	report["support"] = "PASS: two 0.78 m tabletop colliders and two clear capsule approaches"
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440,900)
		root.content_scale_size = root.size
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		var camera := Camera3D.new()
		stage.add_child(camera)
		camera.make_current()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		for view in [["tools",Vector3(0,.03,0),2.65],["work_surfaces",Vector3(0,.45,2.2),3.7],["shuttle",props[3].position,.42],["plane",props[2].position,.42]]:
			for i in props.size():
				props[i].visible = (i<5 if view[0]=="tools" else i>=5 if view[0]=="work_surfaces" else i==3 if view[0]=="shuttle" else i==2)
			camera.size = view[2]
			camera.position = view[1]+Vector3(.8,1.6,1.5)
			camera.look_at(view[1])
			for frame in 10: await process_frame
			RenderingServer.force_draw()
			assert(root.get_texture().get_image().save_png("res://docs/assets/craft_"+view[0]+".png")==OK)
	var suffix := "headless" if DisplayServer.get_name()=="headless" else "metal"
	var file := FileAccess.open("res://docs/assets/craft_validation_"+suffix+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	stage.free()
	print("CRAFT: seven prefabs, markers, tabletop support and approach PASS")
	quit()
