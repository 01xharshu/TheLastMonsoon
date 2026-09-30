extends SceneTree
## Standalone native-render review and physical/pickup checks, without loading dirty world assets.
const SCENES = ["res://objects/water_pot.tscn","res://objects/water_bag.tscn","res://objects/oil_lamp.tscn"]
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
		if i == 0: prop.position.y = .4
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
		for visual in prop.find_children("*","MeshInstance3D",true,false):
			if visual is MeshInstance3D:
				count += 1
				for s in visual.mesh.get_surface_count():
					var arrays: Array = visual.mesh.surface_get_arrays(s)
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					triangles += indices.size()/3 if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()/3
		report.assets.append({"scene":SCENES[i],"ray_contact":true,"mesh_nodes":count,"triangles":triangles})
	var actor := CharacterBody3D.new()
	var inventory := InventoryComponent.new()
	inventory.name = "InventoryComponent"
	actor.add_child(inventory)
	stage.add_child(actor)
	props[0].interact(actor)
	assert(inventory.get_stored_water_liters() == 0.0,"No pouch: pot must not add water")
	props[1].interact(actor)
	assert(inventory.items.get("water_bag",0)==1,"Pouch pickup must grant exactly one pouch")
	await process_frame
	assert(not is_instance_valid(props[1]),"Pouch pickup must remove world object")
	props[0].interact(actor)
	assert(is_equal_approx(inventory.get_stored_water_liters(),2.0),"Pot must fill owned pouch")
	props[0].interact(actor)
	assert(is_equal_approx(inventory.get_stored_water_liters(),2.0),"Full pouch must not overfill")
	inventory.consume_water(.25)
	props[0].interact(actor)
	assert(is_equal_approx(inventory.get_stored_water_liters(),2.0),"Partial pouch must refill")
	report["water_transactions"] = "PASS: no-pouch refusal, pickup/removal, fill, full refusal, partial refill"
	props[1] = load(SCENES[1]).instantiate()
	stage.add_child(props[1])
	var lamp := props[2]
	assert(lamp.is_lit and lamp.get_node("LampLight").visible and lamp.get_node("LampBody/Flame").visible)
	lamp.interact(actor)
	assert(not lamp.is_lit and not lamp.get_node("LampLight").visible and not lamp.get_node("LampBody/Flame").visible)
	lamp.interact(actor)
	assert(lamp.is_lit and lamp.get_node("LampBody/Flame").visible)
	report["lamp_switch"] = "PASS: light and flame switch together"
	var player_scene: PackedScene = load("res://player/player.tscn")
	assert(player_scene != null,"Player scene import")
	var player: Node = player_scene.instantiate()
	assert(player.get_node_or_null("VisualRoot/EquipmentVisuals/WaterBagVisual/PouchModel/Mouth") != null,"Carried pouch must use shared visual/contact markers")
	player.free()
	report["shared_carried_pouch"] = "PASS: player scene references same pouch visual"
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440,900)
		root.content_scale_size = Vector2i(1440,900)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		var camera := Camera3D.new()
		camera.fov = 45
		stage.add_child(camera)
		camera.make_current()
		var views := [
			["overview",Vector3(2.1,2.2,3.6),Vector3(0,.3,0)],
			["water_pot",Vector3(-.65,1.2,1.0),Vector3(-1.4,.42,0)],
			["water_pot_mouth",Vector3(-1.05,1.18,.38),Vector3(-1.4,.65,0)],
			["water_pouch",Vector3(.35,.4,.65),Vector3(0,.20,0)],
			["oil_lamp",Vector3(1.7,.40,.50),Vector3(1.4,.075,.035)]
		]

		for view in views:
			camera.position = view[1]
			camera.look_at(view[2])
			for frame in 12: await process_frame
			# Force a fresh frame even when macOS suppresses background-window redraws.
			RenderingServer.force_draw()
			assert(root.get_texture().get_image().save_png("res://docs/assets/water_light_"+view[0]+".png") == OK)
	var file := FileAccess.open("res://docs/assets/water_light_validation_"+("headless" if DisplayServer.get_name()=="headless" else "metal")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("WATER/LIGHT REVIEW: collision, pouch/pot transactions, lamp switch and player scene PASS; animation deferred")
	stage.queue_free()
	await process_frame
	quit()
