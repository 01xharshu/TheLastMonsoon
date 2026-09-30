extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var clock := preload("res://world/suryagarh/systems/game_time_system.gd").new()
	clock.name = "GameTimeSystem"
	root.add_child(clock)
	var actor: Node3D = load("res://player/player.tscn").instantiate()
	root.add_child(actor)
	await process_frame
	var scope: Node = actor.get_node("FieldTelescope")
	var original: Camera3D = root.get_camera_3d()
	scope.set_active(true)
	assert(root.get_camera_3d() == scope.camera)
	assert(actor.get_meta("telescope_open"))
	assert(not actor.get_node("CombatInput").available())
	for weapon in ["RifleCombat","PistolCombat","BowCombat","TalwarSlash"]:
		assert(not actor.get_node(weapon).available())
	if DisplayServer.get_name() != "headless":
		var light := DirectionalLight3D.new()
		root.add_child(light)
		light.rotation_degrees = Vector3(-40,-30,0)
		var target := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(4,10,4)
		target.mesh = mesh
		root.add_child(target)
		target.position = Vector3(0,0,-60)
		actor.set_physics_process(false)
		scope.set_process(false)
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/telescope_optics.png")
		actor.set_physics_process(true)
		scope.set_process(true)
	scope.zoom_by(100)
	assert(scope.magnification == 12.0)
	assert(scope.camera.fov < 8.0)
	scope.zoom_by(-100)
	assert(scope.magnification == 2.0)
	assert(scope.camera.fov > 40.0)
	scope.set_active(false)
	assert(root.get_camera_3d() == original)
	assert(not actor.get_meta("telescope_open"))
	scope.set_active(true)
	actor.set_meta("map_open",true)
	scope._process(0.016)
	assert(not scope.active)
	actor.set_meta("map_open",false)
	print("FIELD TELESCOPE: PASS camera/zoom/combat exclusion/map release")
	actor.queue_free()
	await process_frame
	quit()
