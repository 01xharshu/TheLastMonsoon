extends SceneTree
const Startup = preload("res://systems/world_startup.gd")
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failed = true; push_error(message)
func run() -> void:
	paused = true
	var session := Startup.start(self)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var cart: Node3D = load("res://vehicles/family_carriage_candidate.gd").new()
	var layout = load("res://world/suryagarh/landscape_layout.gd").new()
	cart.position = Vector3(-265,layout.height(-265,-18),-18)
	cart.rotation.y = PI*.5
	world.add_child(cart)
	await process_frame
	var driver: Node3D = cart.visual_root.get_node("CoachmanMakeHuman")
	while not session.tasks.is_empty(): await process_frame
	check(driver.get_meta("startup_cloth_cache",false),"Starting pose rejected the baked garment")
	var cloth = driver.seated_cloth
	var expected: Array = []
	var body_meshes: Array = []
	for node in driver.find_children("*","MeshInstance3D",true,false):
		if node.skin != null: body_meshes.append([node,node.mesh,node.skin])
	for piece in cloth.pieces:
		var surfaces: Array = []
		for surface in piece.node.mesh.get_surface_count(): surfaces.append(piece.node.mesh.surface_get_arrays(surface))
		expected.append(surfaces)
	cloth.startup_signature = "stale-input"
	check(not cloth._restore_startup_cache(),"Stale body/pose input was accepted")
	var reference_cart: Node3D = load("res://vehicles/family_carriage_candidate.gd").new()
	reference_cart.transform = cart.transform
	reference_cart.set_meta("rebuild_startup_cloth",true)
	world.add_child(reference_cart)
	await process_frame
	while not session.tasks.is_empty(): await process_frame
	var reference: Node3D = reference_cart.visual_root.get_node("CoachmanMakeHuman")
	var reference_cloth = reference.seated_cloth
	var max_position_error := 0.0
	for index in cloth.pieces.size():
		var node: MeshInstance3D = reference_cloth.pieces[index].node
		for surface in node.mesh.get_surface_count():
			var actual: Array = node.mesh.surface_get_arrays(surface)
			for field in Mesh.ARRAY_MAX:
				if field == Mesh.ARRAY_VERTEX:
					for vertex in actual[field].size(): max_position_error = maxf(max_position_error,actual[field][vertex].distance_to(expected[index][surface][field][vertex]))
				else: check(actual[field] == expected[index][surface][field],"Cached garment differs in field %s" % field)
	check(max_position_error < .000001,"Cached garment position changed")
	for retained in body_meshes:
		check(retained[0].mesh == retained[1] and retained[0].skin == retained[2],"Cache replaced the retained MPFB body/foundation")
	Startup.close(session)
	print("COACHMAN CACHE PARITY ",JSON.stringify({"status":"FAIL" if failed else "PASS","max_position_error_m":max_position_error,"retained_skinned_meshes":body_meshes.size()}))
	await root.get_node("SaveManager").quit_game(1 if failed else 0)
