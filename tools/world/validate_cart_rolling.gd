extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)
func run() -> void:
	root.size=Vector2i(1280,720)
	var world:=Node3D.new();root.add_child(world);current_scene=world
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-30,0);world.add_child(light)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.38,.45,.5);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.6;world.add_child(environment)
	var camera:=Camera3D.new();world.add_child(camera)
	var floor:=StaticBody3D.new();world.add_child(floor)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(200,.2,200);shape.shape=box;shape.position.y=-.1;floor.add_child(shape)
	var ground:=MeshInstance3D.new();ground.mesh=BoxMesh.new();ground.mesh.size=box.size;ground.position.y=-.1;world.add_child(ground)
	var clock: Node=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
	var actor: CharacterBody3D=load("res://player/player.tscn").instantiate();world.add_child(actor);actor.set_physics_process(false)
	var index:=0
	for kind in ["ekka","goods","bullock","coach"]:
		var cart: Node3D=load("res://vehicles/"+({"ekka":"horse_cart_candidate","goods":"horse_cart_candidate","bullock":"bullock_cart","coach":"family_carriage_candidate"}[kind])+".gd").new()
		if kind=="goods":cart.variant=1
		world.add_child(cart);cart.position.x=index*15;index+=1
		for frame in 5:await process_frame
		camera.make_current();camera.global_position=cart.to_global(Vector3(-6,3.3,7));camera.look_at(cart.to_global(Vector3(0,1,1.5)))
		var output:=OS.get_environment("TLM_GLOW_REVIEW")
		if DisplayServer.get_name()!="headless" and not output.is_empty():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(kind+"_before.png"))
		var roll: Node=cart.get_node("WheelMotion");roll.set_process(false);roll.reset()
		var wheel: Node3D=cart.wheels[0];var radius: float=wheel.position.y;var before: float=wheel.rotation.x
		cart.position.z-=.5;roll.update_roll(1.0/60)
		check(absf(angle_difference(before,wheel.rotation.x)-.5/radius)<.001,kind+" rolls exact measured displacement without speed command")
		if DisplayServer.get_name()!="headless" and not output.is_empty():
			camera.global_position=cart.to_global(Vector3(-6,3.3,7));camera.look_at(cart.to_global(Vector3(0,1,1.5)))
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(kind+"_rolling.png"))
		before=wheel.rotation.x;cart.set_forward_motion(8,1.0/60);roll.update_roll(1.0/60)
		check(absf(angle_difference(before,wheel.rotation.x))<.001,kind+" blocked/stationary wheels do not spin from commanded speed")
		if kind in ["ekka","goods","coach"]:
			var horse: AnimationPlayer = cart.horse_animations[0] if kind == "coach" else cart.horse_animation
			check(horse.current_animation.ends_with("Idle"),kind+" stationary draft horse stands despite throttle")
			cart.position.z-=.05
			cart.set_forward_motion(8,1.0/60)
			check(horse.current_animation.ends_with("Walk"),kind+" measured slow advance produces walk despite sprint throttle")
			cart.position.z+=.05
		cart.position.z+=.5;roll.update_roll(1.0/60)
		check(absf(wheel.rotation.x)<.001,kind+" reversing rolls back without sliding")
		var left: Node3D=cart.wheels[0];var right: Node3D=cart.wheels[1]
		for candidate in cart.wheels:
			if candidate.position.x>0:right=candidate;break
		var left_before: float=left.rotation.x;var right_before: float=right.rotation.x
		cart.rotation.y+=.1;roll.update_roll(1.0/60)
		check(absf(angle_difference(left_before,left.rotation.x)-angle_difference(right_before,right.rotation.x))>.02,kind+" inner and outer wheels follow different turn distances")
		before=wheel.rotation.x;cart.position.z+=10;roll.update_roll(1.0/60)
		check(absf(angle_difference(before,wheel.rotation.x))<.001,kind+" cinematic/restore teleport resets rolling baseline")
		cart.rotation.y=0
		for frame in 3:await physics_frame
		var low:=cart.to_global(Vector3(-3,.6,2.55))
		var ray:=PhysicsRayQueryParameters3D.create(low,low+Vector3.RIGHT*6,1)
		var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(hit.get("collider")==cart.boarding.collision_body,kind+" lower cart blocks ground-level crossing/projectile ray")
		var wheel_point:=wheel.global_position
		ray=PhysicsRayQueryParameters3D.create(wheel_point+Vector3(-2,0,0),wheel_point+Vector3(2,0,0),1)
		hit=world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(hit.get("collider")==cart.boarding.collision_body,kind+" full wheel volume has physical collision")
		actor.global_position=cart.to_global(Vector3(-3,.95,2.55));actor.velocity=Vector3.ZERO
		var contact:=actor.move_and_collide(Vector3.RIGHT*6)
		check(contact!=null and contact.get_collider()==cart.boarding.collision_body and actor.global_position.x<cart.global_position.x,kind+" actual player capsule cannot walk through cart")
		actor.global_position=Vector3(-30,2,-30)
		check(cart.boarding._clearance_at(cart.global_position),kind+" expanded hull remains clear of level ground and own team")
	if OS.get_environment("TLM_GLOW_REVIEW")!="":
		print("CART REVIEW READY")
		var deadline:=Time.get_ticks_msec()+90000
		while Time.get_ticks_msec()<deadline and not FileAccess.file_exists(OS.get_environment("TLM_GLOW_REVIEW").path_join("cart_done")):await process_frame
	print("CART ROLLING ","PASS" if failures.is_empty() else "FAIL",failures)
	await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures.is_empty() else 1)
