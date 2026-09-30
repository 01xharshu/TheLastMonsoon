extends SceneTree
## Build reusable wrappers around unchanged source assets; review without loading concurrent world edits.
const SOURCE = "res://assets/props/polyhaven/"
const OUT = "res://objects/household/storage/"
const ITEMS = [
	["wooden_crate_02","crate",Vector3(.55,.50,1.17),.24,"box"],
	["wooden_bucket_02","bucket",Vector3(.32,.38,0),.19,"cylinder"],
	["brass_pot_01","brass_pot",Vector3(.16,.30,0),.15,"cylinder"],
	["wicker_basket_01","basket",Vector3(.4,.13,.31),.065,"box"],
	["wooden_stool_01","stool",Vector3(.23,.44,0),.22,"cylinder"],
	["painted_wooden_bench","bench",Vector3(1.2,.90,.53),.45,"box"],
	["wine_barrel_01","barrel",Vector3(.39,.88,0),.44,"cylinder"]
]
var stage: Node3D
var meshes: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func collect(node: Node3D, parent_transform := Transform3D.IDENTITY) -> void:
	var placement: Transform3D = parent_transform*node.transform
	if node is MeshInstance3D:
		meshes.append({"node":node,"transform":placement})
	for child in node.get_children():
		if child is Node3D: collect(child,placement)

func bounds(node: Node3D) -> AABB:
	meshes.clear()
	collect(node)
	var result := AABB()
	var first := true
	for entry in meshes:
		var box: AABB = entry.transform*entry.node.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

func own(node: Node, root_node: Node) -> void:
	for child in node.get_children():
		child.owner = root_node
		# Imported scene children keep their source ownership; repacking them duplicates the meshes.
		if child.scene_file_path.is_empty(): own(child,root_node)

func marker(node: Node3D, label: String, at: Vector3) -> void:
	var point := Marker3D.new()
	point.name = label
	point.position = at
	node.add_child(point)

func build() -> void:
	for item in ITEMS:
		var body := StaticBody3D.new()
		body.name = str(item[1]).to_pascal_case()
		body.add_to_group("solid_period_prop",true)
		body.set_meta("asset_source",SOURCE+item[0]+"/"+item[0]+"_1k.gltf")
		body.set_meta("interaction_status","decorative; hero actions deferred")
		var model: Node3D = load(str(body.get_meta("asset_source"))).instantiate()
		model.name = "Model"
		var original := bounds(model)
		model.position.y -= original.position.y
		body.add_child(model)
		var collider := CollisionShape3D.new()
		collider.name = "CollisionShape3D"
		var size: Vector3 = item[2]
		if item[4] == "box":
			var box := BoxShape3D.new()
			box.size = size
			collider.shape = box
		else:
			var cylinder := CylinderShape3D.new()
			cylinder.radius = size.x
			cylinder.height = size.y
			collider.shape = cylinder
		collider.position.y = float(item[3])-original.position.y
		body.add_child(collider)
		var fitted := bounds(model)
		if item[1] == "bench":
			marker(body,"SeatLeft",Vector3(-.32,.44,0))
			marker(body,"SeatRight",Vector3(.32,.44,0))
			marker(body,"Approach",Vector3(0,0,.85))
		elif item[1] == "stool":
			marker(body,"Seat",Vector3(0,.44,0))
			marker(body,"Approach",Vector3(0,0,.65))
		elif item[1] in ["bucket","basket","brass_pot"]:
			marker(body,"GripLeft",Vector3(fitted.position.x,fitted.end.y,0))
			marker(body,"GripRight",Vector3(fitted.end.x,fitted.end.y,0))
			marker(body,"Opening",Vector3(0,fitted.end.y,0))
		else:
			marker(body,"TopReference",Vector3(0,fitted.end.y,0))
		own(body,body)
		var scene := PackedScene.new()
		assert(scene.pack(body)==OK)
		assert(ResourceSaver.save(scene,OUT+str(item[1])+".tscn")==OK)
		body.free()

func run() -> void:
	if OS.get_cmdline_user_args().has("--build"): build()
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.12,.14,.15)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.80,.84,.88)
	environment.environment.ambient_light_energy = .65
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-30,0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_body := StaticBody3D.new()
	stage.add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(12,.1,12)
	floor_shape.shape = floor_box
	floor_shape.position.y = -.05
	floor_body.add_child(floor_shape)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12,12)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(.29,.31,.28)
	plane.material = floor_mat
	floor_mesh.mesh = plane
	floor_body.add_child(floor_mesh)
	var props: Array[StaticBody3D] = []
	for i in ITEMS.size():
		var prop: StaticBody3D = load(OUT+str(ITEMS[i][1])+".tscn").instantiate()
		prop.position = Vector3((i%3-1)*2.4,0,(floori(float(i)/3.0)-1)*3.4)
		stage.add_child(prop)
		props.append(prop)
	for frame in 3: await physics_frame
	var report := {"renderer":RenderingServer.get_current_rendering_method(),"assets":[],"scope":"standalone wrappers; world placement and hero actions separate"}
	var probe := CharacterBody3D.new()
	var probe_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .25
	capsule.height = 1.8
	probe_shape.shape = capsule
	probe.add_child(probe_shape)
	stage.add_child(probe)
	for i in props.size():
		var prop := props[i]
		var box := bounds(prop.get_node("Model"))
		assert(absf(box.position.y)<.001,"Prefab is not floor-normalized")
		var contacts := 0
		for sign_ in [-1.0,1.0]:
			probe.position = prop.position+Vector3(0,.91,sign_*1.6)
			var hit := probe.move_and_collide(Vector3(0,0,-sign_*1.6))
			assert(hit != null and hit.get_collider()==prop,"Missing front/back contact: "+str(ITEMS[i][1]))
			contacts += 1
		var triangles := 0
		for entry in meshes:
			for surface_index in entry.node.mesh.get_surface_count():
				var arrays: Array = entry.node.mesh.surface_get_arrays(surface_index)
				triangles += arrays[Mesh.ARRAY_INDEX].size()/3
		report.assets.append({"name":ITEMS[i][1],"mesh_bounds":str(box),"floor_gap_m":box.position.y,"capsule_contacts":contacts,"triangles":triangles,"actions":"deferred"})
	probe.queue_free()
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440,900)
		root.content_scale_size = Vector2i(1440,900)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		var camera := Camera3D.new()
		stage.add_child(camera)
		camera.make_current()
		camera.fov = 45
		await capture(camera,Vector3(8,8,10),Vector3(0,.3,0),"overview")
		for i in props.size():
			var box := bounds(props[i].get_node("Model"))
			var center := props[i].position+box.get_center()
			var distance := maxf(.5,maxf(box.size.z,maxf(box.size.x,box.size.y))*1.5)
			await capture(camera,center+Vector3(.8,.55,1.0)*distance,center,str(ITEMS[i][1]))
	var file := FileAccess.open("res://docs/assets/storage_validation_"+("headless" if DisplayServer.get_name()=="headless" else "metal")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("STORAGE BATCH: seven reusable scenes, floor normalization and fourteen capsule contacts PASS")
	meshes.clear()
	props.clear()
	stage.free()
	for frame in 3: await process_frame
	quit()

func capture(camera: Camera3D, eye: Vector3, target: Vector3, label: String) -> void:
	camera.position = eye
	camera.look_at(target)
	for frame in 8: await process_frame
	RenderingServer.force_draw()
	assert(root.get_texture().get_image().save_png("res://docs/assets/storage_"+label+".png")==OK)
