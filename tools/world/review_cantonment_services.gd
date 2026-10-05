extends SceneTree
# Isolated production cantonment review; does not certify full-world health or Arjun motion.
class ReviewBuilder extends Node3D:
	var plaster: Material
	var ochre: Material
	var brick: Material
	var wood: Material
	var tile: Material
	var stone: Material
	var iron: Material
	func piece(parent: Node3D, label: String, p: Vector3, size: Vector3, mat: Material, solid := true) -> Node3D:
		var node := Node3D.new()
		node.name = label
		parent.add_child(node)
		node.position = p
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
		mesh.material_override = mat
		node.add_child(mesh)
		if solid:
			var body := StaticBody3D.new()
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = size
			collision.shape = shape
			body.add_child(collision)
			node.add_child(body)
		return node
	func merge_visuals(_parent: Node3D) -> void: pass
func _initialize() -> void: run.call_deferred()
func run() -> void:
	print("SERVICE FIXTURE START")
	root.size = Vector2i(1280,720)
	var world := Node3D.new()
	world.set_meta("service_geometry_fixture",true)
	root.add_child(world)
	current_scene = world
	var builder := ReviewBuilder.new()
	world.add_child(builder)
	var detail = preload("res://world/suryagarh/settlements/military_detail.gd")
	builder.plaster = detail.surface(Color(.76,.70,.56))
	builder.ochre = detail.surface(Color(.55,.40,.24))
	builder.brick = detail.surface(Color(.44,.24,.16),1)
	builder.wood = detail.surface(Color(.23,.13,.07),2)
	builder.tile = detail.surface(Color(.43,.19,.105),3)
	builder.stone = detail.surface(Color(.42,.40,.33))
	builder.iron = detail.surface(Color(.13,.14,.13))
	builder.piece(world,"ReviewGround",Vector3(500,8.45,470),Vector3(145,.1,125),builder.ochre)
	preload("res://world/suryagarh/settlements/cantonment.gd").new().build(builder)
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(.52,.62,.68)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(.75,.78,.82)
	settings.ambient_light_energy = .55
	env.environment = settings
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-30,0)
	sun.shadow_enabled = true
	world.add_child(sun)
	print("SERVICE GEOMETRY BUILT")
	for frame in 8: await physics_frame
	var district: Node3D = builder.get_node("BritishCantonment")
	var manager: Node3D = district.get_node("ServiceWorkplaces")
	assert(manager.workers.size()==5)
	var body_vertices := 0
	var foundation_vertices := 0
	var worker_clearances := 0
	for actor in manager.workers:
		var complete := false
		var foundation := false
		for mesh in actor.find_children("*","MeshInstance3D",true,false):
			if "export_full_body" in str(mesh.name):
				complete = mesh.skin != null
				body_vertices += mesh.mesh.surface_get_array_len(0)
			if "foundation" in str(mesh.name):
				foundation = mesh.skin != null
				foundation_vertices += mesh.mesh.surface_get_array_len(0)
		assert(complete and foundation,"Worker missing complete skinned MPFB body/foundation")
		var body: PhysicsBody3D = actor.get_node("BodyCollider")
		var shape_node: CollisionShape3D = body.get_node("BodyShape")
		var worker_query := PhysicsShapeQueryParameters3D.new()
		worker_query.shape = shape_node.shape
		worker_query.transform = shape_node.global_transform
		worker_query.transform.origin.y += .015
		var own_bodies: Array[RID] = []
		for own_body in actor.find_children("*","PhysicsBody3D",true,false): own_bodies.append(own_body.get_rid())
		worker_query.exclude = own_bodies
		var occupancy_hits := world.get_world_3d().direct_space_state.intersect_shape(worker_query)
		for hit in occupancy_hits: print("WORKPLACE HIT ",actor.name," at ",worker_query.transform.origin," with ",hit.collider.get_path())
		assert(occupancy_hits.is_empty(),"Worker intersects workplace: "+str(actor.name))
		worker_clearances += 1
	manager.update_activity(Vector3(500,9,515))
	assert(manager.active_workers<=3)
	manager.update_activity(Vector3(1000,9,1000))
	assert(manager.active_workers==0)
	var scheduling_usec := 0
	for i in 100:
		manager.update_activity(Vector3(500+i,9,515))
		scheduling_usec += manager.update_usec
	manager.set_process(false)
	print("WORKER CHECKS PASS")
	var samples := 0
	var capsule := CapsuleShape3D.new()
	capsule.radius = .35
	capsule.height = 1.8
	for label in ["GrainFodderWarehouse","CavalryStables","MilitaryHospital","CantonmentChurch","MilitaryCemetery"]:
		var site: Node3D = district.get_node(label)
		var end_z := 2.0 if label == "CavalryStables" else 0.0
		var start_z: float = site.get_node("Entrance").position.z-1.3
		for i in 20:
			var z: float = lerpf(start_z,end_z,i/19.0)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.transform.origin = site.to_global(Vector3(0,.91+(.25 if label != "MilitaryCemetery" else .04),z))
			assert(world.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"Fixture capsule obstruction: "+label)
			samples += 1
	var room_door_samples := 0
	for route in [
		["MilitaryHospital",Vector3(-5,.25,0),Vector3(-7,.25,0)],
		["MilitaryHospital",Vector3(5,.25,0),Vector3(7,.25,0)],
		["MilitaryHospital",Vector3(0,.25,-.3),Vector3(0,.25,-2.0)],
		["GrainFodderWarehouse",Vector3(-6,.25,1.5),Vector3(-6,.25,2.7)],
		["CavalryStables",Vector3(-12.5,.25,1.2),Vector3(-12.5,.25,2.3)],
		["CantonmentChurch",Vector3(-3.85,.45,-3.0),Vector3(-3.85,.45,-4.4)]
	]:
		var site: Node3D = district.get_node(route[0])
		for i in 12:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.transform.origin = site.to_global(route[1].lerp(route[2],i/11.0)+Vector3(0,.91,0))
			var hits := world.get_world_3d().direct_space_state.intersect_shape(query)
			for hit in hits: print("ROOM HIT ",route[0]," at ",query.transform.origin," ",hit.collider.get_path())
			assert(hits.is_empty(),"New service-room doorway obstructed: "+route[0])
			room_door_samples += 1
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	for spec in [
		["GrainFodderWarehouse","warehouse_interior",Vector3(0,2.1,4.4),Vector3(0,1.2,-2)],
		["GrainFodderWarehouse","issue_office",Vector3(-6,2.0,2.55),Vector3(-6,1.2,4.2)],
		["MilitaryHospital","dressing_room",Vector3(0,2.0,-1.4),Vector3(0,1.2,-3.5)],
		["CantonmentChurch","vestry",Vector3(-3.8,2.0,-3.9),Vector3(-3.8,1.3,-5.5)],
		["GrainFodderWarehouse","warehouse_fodder",Vector3(1,2.0,0),Vector3(6,.7,2)],
		["GrainFodderWarehouse","warehouse_exterior",Vector3(13,6,17),Vector3(0,1.5,0)],
		["CavalryStables","stables_interior",Vector3(12,2.1,3.8),Vector3(-7,1.1,-1.5)],
		["CavalryStables","manger",Vector3(12,1.8,-2.2),Vector3(13.8,.85,-3.5)],
		["CavalryStables","stables_exterior",Vector3(22,7,19),Vector3(0,1.5,0)],
		["MilitaryHospital","hospital_interior",Vector3(0,2.1,4.3),Vector3(-3,1,-2)],
		["MilitaryHospital","hospital_exterior",Vector3(18,6,17),Vector3(0,1.5,0)],
		["CantonmentChurch","church_interior",Vector3(0,2.1,6.3),Vector3(0,1.3,-5)],
		["CantonmentChurch","church_exterior",Vector3(12,6,16),Vector3(0,2,0)],
		["MilitaryCemetery","cemetery_gate",Vector3(8,3,16),Vector3(0,1,0)],
		["MilitaryCemetery","cemetery_inside",Vector3(0,1.8,8),Vector3(-3,1,-5)]
	]:
		var site: Node3D = district.get_node(spec[0])
		camera.global_position = site.to_global(spec[2])
		camera.look_at(site.to_global(spec[3]))
		for frame in 4: await process_frame
		if DisplayServer.get_name() == "headless": continue
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://docs/world/captures/service_fixture_"+spec[1]+".png")
	var report := {"date":"2026-10-05","room_door_samples":room_door_samples,"workers":5,"complete_body_vertices":body_vertices,"foundation_vertices":foundation_vertices,"worker_clearances":worker_clearances,"worker_build_usec":manager.get_meta("build_usec"),"mean_schedule_usec":scheduling_usec/100.0,"max_active_workers":3,"fixture_capsule_samples":samples,"renderer":RenderingServer.get_current_rendering_method(),"scope":"production service geometry and full-body workers in isolated fixture; workplace collision and scheduler measured; full-world routes checked separately"}
	var file := FileAccess.open("res://docs/world/cantonment_service_fixture_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("SERVICE FIXTURE PASS: ",samples," aisle + ",room_door_samples," room door capsule samples; five workers; fifteen native captures")
	quit()
