extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for frame in 5: await physics_frame
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	var props := get_nodes_in_group("asset_first_craft")
	assert(props.size()==2,"Both workshop surfaces must be integrated")
	var report := {"workshops":[],"limits":"support, short approach capsule checks and native render; no crafting action or final hero contact approval"}
	for prop in props:
		var exclude: Array[RID] = []
		for body in prop.find_children("*","CollisionObject3D",true,false): exclude.append(body.get_rid())
		var ray := PhysicsRayQueryParameters3D.create(prop.global_position+Vector3.UP*.2,prop.global_position-Vector3.UP)
		ray.exclude = exclude
		var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
		assert(not hit.is_empty() and absf(prop.global_position.y-hit.position.y)<.05,"Workshop floor support")
		var capsule := CapsuleShape3D.new()
		capsule.height = 1.7
		capsule.radius = .3
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.exclude = [player.get_rid()]
		var approach: Node3D = prop.get_node("Approach")
		for sample in 8:
			query.transform.origin = approach.global_position+approach.global_basis*Vector3(0,.94,sample*.15)
			var overlaps := world.get_world_3d().direct_space_state.intersect_shape(query)
			assert(overlaps.is_empty(),"Workshop approach obstruction: "+str(overlaps))
		report.workshops.append({"node":str(prop.get_path()),"support_gap_m":prop.global_position.y-hit.position.y,"approach_m":1.05,"meshes":prop.find_children("*","MeshInstance3D",true,false).size()})
	var armoury: Node3D = world.get_node("Settlement/CompanyArmoury")
	var rack: Node3D = armoury.get_node("WeaponRackDressing")
	assert(rack.get_node_or_null("LowerShelfReach") != null)
	var ids: Array[String] = []
	for weapon in get_nodes_in_group("weapon_pickups"):
		if armoury.is_ancestor_of(weapon): ids.append(weapon.persistence_id())
	assert(ids.size()==5,"Rack dressing must not duplicate pickups")
	report["weapon_ids"] = ids
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440,900)
		root.content_scale_size = root.size
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		var camera := Camera3D.new()
		camera.fov = 55
		world.add_child(camera)
		camera.make_current()
		for prop in props+[rack]:
			var offset := Vector3(1.4,1.5,2.3) if prop!=rack else Vector3(2.5,2.2,4)
			camera.global_position = prop.global_position+prop.global_basis*offset
			camera.look_at(prop.global_position+Vector3.UP*(.55 if prop!=rack else 1.2))
			for frame in 8: await process_frame
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://docs/assets/integrated_"+str(prop.name).to_snake_case()+".png")
	var suffix := "headless" if DisplayServer.get_name()=="headless" else "metal"
	var file := FileAccess.open("res://docs/assets/craft_rack_integration_"+suffix+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("CRAFT/RACK INTEGRATION PASS: both supports/approaches, retained five weapon IDs")
	quit()
