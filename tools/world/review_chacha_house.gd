extends SceneTree
## Disposable screenshots only in explicitly supplied OS temporary directory.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=OS.get_environment("TLM_CHACHA_REVIEW_DIR")
	if not output.begins_with(OS.get_environment("TMPDIR")) or output.is_empty():quit(2);return
	var world:=Node3D.new();root.add_child(world)
	var time=load("res://world/suryagarh/systems/game_time_system.gd").new();time.name="GameTimeSystem";world.add_child(time)
	var player: CharacterBody3D=load("res://player/player.tscn").instantiate();player.name="Player";world.add_child(player)
	var house=load("res://world/suryagarh/settlements/chacha_house.gd").new();world.add_child(house)
	var environment:=WorldEnvironment.new();world.add_child(environment);environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.4,.5,.57);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7
	var sun:=DirectionalLight3D.new();world.add_child(sun);sun.rotation_degrees=Vector3(-45,-30,0);sun.light_energy=1.3
	player.global_position=house.to_global(Vector3(0,1.1,0))
	player.inventory.add_item("spear",1);player.get_node("ChachaKit").equip("spear")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var camera:=Camera3D.new();world.add_child(camera);camera.current=true
	for view in ["exterior","weapons","stairs","spear"]:
		camera.global_position=house.to_global({"exterior":Vector3(15,12,19),"weapons":Vector3(0,2,-1.5),"stairs":Vector3(3.2,4.5,3.6),"spear":Vector3(2,1.9,2.5)}[view]);camera.look_at(house.to_global({"exterior":Vector3(0,1.8,0),"weapons":Vector3(0,1.35,-4.4),"stairs":Vector3(5,2,-1.2),"spear":Vector3(0,1.1,0)}[view]))
		await create_timer(.5).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/"+view+".png")
	camera.global_position=house.to_global(Vector3(2,1.9,-2));camera.look_at(player.global_position+Vector3(0,.2,0))
	player.get_node("ChachaKit").strike()
	for phase in ["thrust_start","thrust_contact","thrust_recover"]:
		await create_timer(.15).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/"+phase+".png")
	var uncle: Node3D=house.get_node("Chacha")
	uncle.state="talking"
	player.global_position=house.to_global(Vector3(0,1.1,4.7))
	var conversation: Node=house.get_node("ChachaAdvice")
	conversation.interact(player)
	camera.global_position=house.to_global(Vector3(1.3,1.8,5));camera.look_at(uncle.global_position+Vector3.UP)
	await create_timer(1).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/chacha_gesture.png")
	conversation._process(float(conversation.LINES[0].seconds)-conversation.elapsed)
	await create_timer(.5).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/arjun_reply.png")
	print("CHACHA REVIEW rendered")
	world.queue_free();await process_frame;quit()
