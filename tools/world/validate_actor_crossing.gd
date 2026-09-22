extends SceneTree
var failed := false
func _initialize() -> void:
	call_deferred("validate")
func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
func validate() -> void:
	var world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var player = world.get_node("Player")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	var bridge = world.get_node("TimberBridge")
	var map = player.get_node("UI/WorldMap")
	for i in 5: await physics_frame
	check(player.get_node("VisualRoot/CharacterVisual").skeleton.get_bone_count()>40,"Arjun rig missing")
	var space = world.get_world_3d().direct_space_state
	for i in range(-87,88):
		var x: float = bridge.position.x+i
		var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,30,165),Vector3(x,-10,165)))
		check(not hit.is_empty(),"Missing crossing floor at %s" % i)
		if not hit.is_empty(): check(hit.position.y>0,"Crossing is underwater")
	for direction in ([] if "--capture-only" in OS.get_cmdline_user_args() else [1.0,-1.0]):
		player.position = Vector3(bridge.position.x-direction*89,bridge.layout.height(bridge.position.x-direction*89,165)+1.0,165)
		for step in 1800:
			player.velocity = Vector3(direction*7.0,player.velocity.y-9.8/60.0,0)
			player.move_and_slide()
			await physics_frame
		check(direction*(player.position.x-bridge.position.x)>89,"Could not traverse bridge direction %s; stopped at %s" % [direction,player.position])
	map.set_open(true)
	check(map.visible and player.get_meta("map_open"),"Map did not open")
	for i in 3: await process_frame
	if not DisplayServer.get_name() == "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/08_map.png")
	map.set_open(false)
	check(not player.get_meta("map_open"),"Map did not release gameplay")
	if not DisplayServer.get_name() == "headless":
		player.position = Vector3(bridge.position.x-56,bridge.deck_height+0.95,165)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = player.position+Vector3(3,1.2,4)
		camera.look_at(player.position+Vector3(0,0.1,0))
		camera.make_current()
		for i in 15: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/07_arjun_bridge.png")
		player.get_node("UI").hide()
		camera.position = bridge.position+Vector3(-90,35,65)
		camera.look_at(bridge.position+Vector3(0,bridge.deck_height,0))
		for i in 10: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/09_bridge.png")
	print("ACTOR / BRIDGE / MAP: ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
