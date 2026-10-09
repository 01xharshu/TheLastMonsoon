extends SceneTree
## Retained rebuild input. Bakes the existing fitted garment, never the human body.
const Startup = preload("res://systems/world_startup.gd")
func _initialize() -> void: run.call_deferred()
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
	cart.set_meta("rebuild_startup_cloth",true)
	world.add_child(cart)
	await process_frame
	var driver: Node3D = cart.visual_root.get_node("CoachmanMakeHuman")
	while not session.tasks.is_empty(): await process_frame
	var cloth = driver.seated_cloth
	var cache := Resource.new()
	cache.set_meta("revision",cloth.CACHE_REVISION)
	cache.set_meta("signature",cloth.source_signature())
	var meshes := {}
	for piece in cloth.pieces: meshes[str(piece.node.name)] = piece.node.mesh
	cache.set_meta("meshes",meshes)
	var temporary: String = cloth.CACHE_PATH.trim_suffix(".res") + ".building.res"
	var error := ResourceSaver.save(cache,temporary)
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(cloth.CACHE_PATH))
	if error != OK: DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	print("COACHMAN STARTUP CACHE ","PASS" if error == OK else "FAIL"," pieces=",meshes.size()," signature=",cache.get_meta("signature"))
	Startup.close(session)
	await root.get_node("SaveManager").quit_game(0 if error == OK else 1)
