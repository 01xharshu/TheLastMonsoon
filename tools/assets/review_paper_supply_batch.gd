extends SceneTree
const NAMES = ["folded_letter","record_folio","supply_parcel","bandage_roll"]
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
	mesh.size = Vector3(2,.02,1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.24,.27,.28)
	mesh.material = mat
	floor_.mesh = mesh
	floor_.position.y = -.01
	stage.add_child(floor_)
	var report := {"assets":[],"scope":"visual prefabs; world collision/gameplay and animation remain separate"}
	for i in NAMES.size():
		var prop: Node3D = load("res://objects/household/supplies/"+NAMES[i]+".tscn").instantiate()
		prop.position.x = (i-1.5)*.48
		stage.add_child(prop)
		assert(prop.get_node_or_null("LeftGrip") != null and prop.get_node_or_null("RightGrip") != null)
		assert(prop.get_script() == null)
		var bounds := AABB()
		var first := true
		var triangles := 0
		for part in prop.find_children("*","MeshInstance3D",true,false):
			var box_: AABB = part.transform * part.get_aabb()
			bounds = box_ if first else bounds.merge(box_)
			first = false
			for s in part.mesh.get_surface_count():
				var arrays: Array = part.mesh.surface_get_arrays(s)
				var ids: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				triangles += ids.size()/3 if not ids.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()/3
		assert(bounds.position.y >= -.001 and bounds.size.length() > .1)
		report.assets.append({"name":NAMES[i],"size_m":str(bounds.size),"triangles":triangles,"floor_and_grips":"PASS"})
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440,900)
		root.content_scale_size = root.size
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		var camera := Camera3D.new()
		stage.add_child(camera)
		camera.make_current()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 1.95
		camera.position = Vector3(.15,1.7,1.3)
		camera.look_at(Vector3.ZERO)
		for frame in 12: await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/assets/paper_supply_overview.png")
		for i in NAMES.size():
			camera.size = .53
			var target := Vector3((i-1.5)*.48,.03,0)
			camera.position = target+Vector3(.13,.48,.35)
			camera.look_at(target)
			for frame in 8: await process_frame
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://docs/assets/paper_supply_"+NAMES[i]+".png")
	var suffix := "headless" if DisplayServer.get_name() == "headless" else "metal"
	var file := FileAccess.open("res://docs/assets/paper_supply_validation_"+suffix+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	stage.free()
	print("PAPER/SUPPLY: floor bounds and grip markers PASS")
	quit()
