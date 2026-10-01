extends SceneTree
## Actual player routes, river connection and physical sea containment.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
var failures: Array[String] = []
var routes: Array[Dictionary] = []
var world: Node3D
var player: CharacterBody3D
var port: Node3D
var layout := Layout.new()

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func settle(at: Vector3) -> void:
	Input.action_release("move_forward")
	player.global_position = at
	player.velocity = Vector3.ZERO
	for i in 12: await physics_frame

func walk_to(target: Vector3, label: String, expected_floor: float, allow_swimming := false) -> void:
	var start := player.global_position
	var limit := ceili(Vector2(target.x-start.x,target.z-start.z).length()/player.walk_speed*60.0)+180
	var arrived := false
	var ever_swimming := false
	Input.action_press("move_forward")
	for i in limit:
		var direction := target-player.global_position
		direction.y = 0
		if direction.length()<0.08:
			arrived = true
			break
		player.get_node("CameraPivot").global_rotation.y = atan2(-direction.x,-direction.z)
		await physics_frame
		ever_swimming = ever_swimming or player.is_swimming
	Input.action_release("move_forward")
	player.velocity = Vector3.ZERO
	for i in 6: await physics_frame
	var end := player.global_position
	print("ROUTE ",label," ",start," -> ",end," target=",target)
	check(arrived and Vector2(end.x-target.x,end.z-target.z).length()<0.5,label+" reaches destination")
	check(absf(end.y-(expected_floor+0.9))<0.18 and player.is_on_floor(),label+" remains supported")
	check(not ever_swimming or allow_swimming,label+" water state is appropriate")
	routes.append({"label":label,"start":str(start),"finish":str(end),"arrived":arrived,"swimming":ever_swimming})
	if not failures.is_empty():
		FileAccess.open("res://docs/world/hooghly_port_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"FAIL","routes":routes,"failures":failures},"\t")+"\n")
		quit(1)

func ship_point(x: float,z: float,y: float=4.22) -> Vector3:
	return port.SHIP_AT+Vector3(x,y,z)

func run() -> void:
	world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	player = world.get_node("Player")
	port = world.get_node("HooghlyPort")
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 12: await physics_frame
	# The centre of the connected river remains navigable to the sea boundary.
	var samples := 0
	for z in range(400,820,4):
		var x: float = layout.river_x(z)
		if layout.height(x,z)>=-3.0: failures.append("channel too shallow "+str(z))
		var ray := PhysicsRayQueryParameters3D.create(Vector3(x,2,z),Vector3(x,-20,z))
		ray.exclude = [player.get_rid()]
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or absf(hit.position.y-layout.height(x,z))>0.18:
			failures.append("baked channel mismatch "+str(z))
		samples += 1
	check(layout.river_width(810)>layout.river_width(450)*5,"river opens into estuary")
	check(failures.is_empty(),"105 channel samples match navigable baked terrain")
	check(port.boundary.find_children("*","GeometryInstance3D",true,false).is_empty(),"sea boundary has no visible wall mesh")
	await settle(Vector3(-168,3.8,680))
	await walk_to(Vector3(-102,4.22,680),"quay to supported jetty",3.32)
	await walk_to(Vector3(-102,4.22,684),"berth turn",3.32)
	await walk_to(ship_point(-3,4),"gangway boards ship",3.32)
	await walk_to(ship_point(-3,11.7),"main deck to stern",3.32)
	await walk_to(ship_point(-1.5,11.7),"around mizzen approach",3.32)
	await walk_to(ship_point(-1.3,14.2),"pass mizzen mast",3.32)
	await walk_to(ship_point(0,14.2),"align with cabin doorway",3.32)
	await walk_to(ship_point(0,16.5),"captain cabin doorway",3.32)
	await walk_to(ship_point(0,18.3),"captain cabin exploration",3.32)
	await walk_to(ship_point(0,14.2),"captain cabin exit",3.32)
	await walk_to(ship_point(2.7,11.65),"poop stair approach",3.32)
	await walk_to(ship_point(2.7,16.2,7),"climb to poop",6.09)
	await walk_to(ship_point(1.1,19.4,7),"helm exploration",6.09)
	await walk_to(ship_point(2.7,16.2,7),"return to poop stairs",6.09)
	await walk_to(ship_point(2.7,11.6),"descend poop stairs",3.32)
	await walk_to(ship_point(3.65,11.6),"move around deck cargo",3.32)
	await walk_to(ship_point(3.65,1.0),"main deck starboard aisle",3.32)
	await walk_to(ship_point(-3.3,1.0),"cross forward of companionway",3.32)
	await walk_to(ship_point(-3.3,-12.7),"forward deck port aisle",3.32)
	await walk_to(ship_point(2,-12.7),"cross behind foremast",3.32)
	await walk_to(ship_point(2,-14.7),"forecastle stair approach",3.32)
	await walk_to(ship_point(2,-19,5.24),"forecastle ascent",4.34)
	await walk_to(ship_point(0,-20.5,5.24),"forecastle exploration",4.34)
	await walk_to(ship_point(2,-19,5.24),"forecastle return",4.34)
	await walk_to(ship_point(2,-14.7),"forecastle descent",3.32)
	await walk_to(ship_point(2,-12.7),"clear foremast on return",3.32)
	await walk_to(ship_point(-3.3,-12.7),"return to port aisle",3.32)
	await walk_to(ship_point(-3.3,1.0),"forward deck return",3.32)
	await walk_to(ship_point(0,1.0),"companionway approach",3.32)
	await walk_to(ship_point(0,11,-0.12),"descend into cargo hold",-1.02)
	await walk_to(ship_point(0,15,-0.12),"cargo hold aft exploration",-1.02)
	await walk_to(ship_point(0,11,-0.12),"return below stairs",-1.02)
	# Walk past the stairs on the port side to the forward crew berths.
	await walk_to(ship_point(-2.0,11,-0.12),"hold side aisle",-1.02)
	await walk_to(ship_point(-2.0,-10,-0.12),"forward hold route",-1.02)
	await walk_to(ship_point(0,-14,-0.12),"crew berth exploration",-1.02)
	await walk_to(ship_point(-2.0,-10,-0.12),"crew berth return",-1.02)
	await walk_to(ship_point(-2.0,11,-0.12),"return to companionway",-1.02)
	await walk_to(ship_point(0,11,-0.12),"hold stair alignment",-1.02)
	await walk_to(ship_point(0,1.0),"climb back to weather deck",3.32)
	# Confirm real swimming is enabled outside the sealed hull and physically stops.
	await settle(Vector3(40,-0.25,815))
	check(player.is_swimming,"sea supports surface swimming")
	player.get_node("CameraPivot").global_rotation.y = PI
	Input.action_press("move_forward")
	for i in 180: await physics_frame
	Input.action_release("move_forward")
	var sea_stop_position := player.global_position
	check(player.global_position.z>818 and player.global_position.z<819.2,"actual swimmer is stopped by invisible boundary")
	check(player.is_swimming,"boundary leaves swimmer buoyant")
	for y in [-12.0,0.0,20.0]:
		var ray := PhysicsRayQueryParameters3D.create(Vector3(40,y,815),Vector3(40,y,825))
		ray.exclude = [player.get_rid()]
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider==port.boundary,"boundary seals height "+str(y))
	# Return from water onto the tidal landing using the same controller.
	await settle(Vector3(-138,-0.25,712))
	await walk_to(Vector3(-153,3.7,712),"swimmer returns by tidal steps",2.8,true)
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","renderer":RenderingServer.get_current_rendering_method(),"channel_samples":samples,"routes":routes,"sea_stop_position":str(sea_stop_position),"sea_boundary_z":Layout.SEA_LIMIT_Z,"failures":failures}
	FileAccess.open("res://docs/world/hooghly_port_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("HOOGHLY PORT VALIDATION ",report.status," ",failures)
	quit(0 if failures.is_empty() else 1)
