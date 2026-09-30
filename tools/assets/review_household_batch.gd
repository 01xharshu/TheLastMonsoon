extends SceneTree
## Standalone native-render review and physical/pickup checks, without loading dirty world assets.
const SCENES = ["res://objects/roti.tscn","res://objects/household/grain_sack.tscn","res://objects/household/woven_mat.tscn"]
var stage: Node3D

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.11,.13,.14)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.78,.84,.9)
	environment.environment.ambient_light_energy = .55
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-30,0)
	light.light_energy = 1.7
	light.shadow_enabled = true
	stage.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6,.1,4)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.27,.29,.27)
	material.roughness = 1.0
	box.material = material
	floor_mesh.mesh = box
	floor_mesh.position.y = -.05
	stage.add_child(floor_mesh)
	var props: Array[Node3D] = []
	for i in SCENES.size():
		var prop: Node3D = load(SCENES[i]).instantiate()
		prop.position.x = (i-1)*1.4
		stage.add_child(prop)
		props.append(prop)
	for frame in 3: await physics_frame
	var report: Dictionary = {"renderer": RenderingServer.get_current_rendering_method(),"assets":[]}
	for i in props.size():
		var prop: Node3D = props[i]
		var target := prop.global_position+Vector3.UP*.01
		var hit := stage.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(target+Vector3.UP,target+Vector3.DOWN*.1))
		assert(not hit.is_empty() and hit.collider == prop,"Asset collision missing: "+SCENES[i])
		var count := 0
		var triangles := 0
		for visual in prop.get_children():
			if visual is MeshInstance3D:
				count += 1
				for s in visual.mesh.get_surface_count():
					triangles += visual.mesh.surface_get_array_index_len(s)/3
		report.assets.append({"scene":SCENES[i],"ray_contact":true,"mesh_nodes":count,"triangles":triangles})
	var actor := CharacterBody3D.new()
	var inventory := InventoryComponent.new()
	inventory.name = "InventoryComponent"
	actor.add_child(inventory)
	stage.add_child(actor)
	props[0].interact(actor)
	assert(inventory.has_item("roti") and inventory.items["roti"]==1,"Roti pickup transaction")
	await process_frame
	assert(not is_instance_valid(props[0]),"Roti pickup must remove world object")
	report["roti_pickup"] = "PASS: one item added, world pickup removed"
	props[0] = load(SCENES[0]).instantiate()
	props[0].position.x = -1.4
	stage.add_child(props[0])
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440,900)
		root.content_scale_size = Vector2i(1440,900)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		var camera := Camera3D.new()
		camera.fov = 45
		stage.add_child(camera)
		camera.make_current()
		var views := [
			["overview",Vector3(2.1,2.6,4.0),Vector3(0,.15,0)],
			["roti",Vector3(-1.12,.36,.40),Vector3(-1.4,.01,0)],
			["grain_sack",Vector3(.8,.7,1.1),Vector3(0,.28,0)],
			["woven_mat",Vector3(2.4,1.0,1.3),Vector3(1.4,0,0)]
		]
		for view in views:
			camera.position = view[1]
			camera.look_at(view[2])
			for frame in 12: await process_frame
			# Force a fresh frame even when macOS suppresses background-window redraws.
			RenderingServer.force_draw()
			assert(root.get_texture().get_image().save_png("res://docs/assets/household_"+view[0]+".png") == OK)
	var file := FileAccess.open("res://docs/assets/household_validation_"+("headless" if DisplayServer.get_name()=="headless" else "metal")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("HOUSEHOLD REVIEW: collision and roti pickup PASS; animation review remains OPEN")
	stage.queue_free()
	await process_frame
	quit()
