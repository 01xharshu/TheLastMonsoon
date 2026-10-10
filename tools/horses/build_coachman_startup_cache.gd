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
	var bullock := "--bullock" in OS.get_cmdline_user_args()
	var cart: Node3D = load("res://vehicles/bullock_cart.gd" if bullock else "res://vehicles/family_carriage_candidate.gd").new()
	var layout = load("res://world/suryagarh/landscape_layout.gd").new()
	cart.position = Vector3(-265,layout.height(-265,-18),-18)
	cart.rotation.y = PI*.5
	cart.set_meta("rebuild_startup_cloth",true)
	world.add_child(cart)
	await process_frame
	var driver: Node3D = cart.visual_root.get_node("MPFBBullockDriver" if bullock else "CoachmanMakeHuman")
	while not session.tasks.is_empty(): await process_frame
	var cloth = driver.seated_cloth
	var cache := Resource.new()
	cache.set_meta("revision",cloth.CACHE_REVISION)
	cache.set_meta("signature",cloth.source_signature())
	var meshes := {}
	for piece in cloth.pieces:
		# Runtime restoration always applies this actor's source materials as
		# overrides. Embedded copies would pin unused materials/textures and
		# inflate the cache; retain only the exact fitted geometry here.
		var geometry: ArrayMesh = piece.node.mesh.duplicate()
		for surface in geometry.get_surface_count(): geometry.surface_set_material(surface,null)
		meshes[str(piece.node.name)] = geometry
	cache.set_meta("meshes",meshes)
	var cache_path: String = cloth.startup_cache_path()
	var temporary: String = cache_path.trim_suffix(".res") + ".building.res"
	var error := ResourceSaver.save(cache,temporary,ResourceSaver.FLAG_COMPRESS)
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(cache_path))
	if error != OK: DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	print("COACHMAN STARTUP CACHE ","PASS" if error == OK else "FAIL"," path=",cache_path," pieces=",meshes.size()," signature=",cache.get_meta("signature"))
	Startup.close(session)
	await root.get_node("SaveManager").quit_game(0 if error == OK else 1)
