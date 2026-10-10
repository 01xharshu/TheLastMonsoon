extends SceneTree
## Existing complete MPFB occupants, boarding, speech and attached exterior lamp.
var errors:Array[String]=[]
var output:=""
class FixtureWorld:
 extends Node3D
 var layout=preload("res://world/suryagarh/landscape_layout.gd").new()
func _initialize() -> void:run.call_deferred()
func check(value:bool,message:String) -> void:
 if not value:errors.append(message);push_error(message)
func run() -> void:
 var saves:Node=root.get_node("SaveManager")
 saves.options.fullscreen=false;saves.options.graphics_quality=0;saves.apply_options()
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
 var world:=FixtureWorld.new();world.name="PublicCartFixture";root.add_child(world);current_scene=world
 var clock:=preload("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock);clock.total_game_minutes=22*60;clock.clock_paused=true;clock._update_readable_time(true)
 var floor:=StaticBody3D.new();var support:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(30,.2,30);support.shape=box;support.position.y=-.1;floor.add_child(support);world.add_child(floor)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,20,0);sun.light_energy=.6;world.add_child(sun)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.045,.065,.10);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color(.3,.36,.5);environment.environment.ambient_light_energy=.5;world.add_child(environment)
 var cart:Node3D=preload("res://vehicles/bullock_cart.gd").new();world.add_child(cart)
 var service:Node3D=preload("res://vehicles/public_passenger_service.gd").install(cart)
 var camera:=Camera3D.new();camera.position=Vector3(5,3.4,-.3);world.add_child(camera);camera.look_at(Vector3(0,1.55,1.8));camera.current=true
 for frame in 20:await physics_frame
 check(cart.seat_sockets.size()>=5,"Four real passenger sockets plus driver")
 check(cart.get_meta("npc_occupied_seats",[]).size()==2,"Two occupied passenger seats and two free seats")
 check(cart.boarding.travel.passenger_service(),"Public cart offers passenger fares")
 var driver:Node3D=cart.driver;check(is_instance_valid(driver),"Existing MakeHuman driver")
 var head:int=driver._skeleton.find_bone("head");var before:Quaternion=driver._skeleton.get_bone_pose_rotation(head)
 service.announce_arrival("Bhairavpur")
 for frame in 15:await physics_frame
 check(driver.get_meta("driver_speaking",false) and service.caption.visible,"Arrival dialogue drives speaking state")
 check(driver._skeleton.get_bone_pose_rotation(head).angle_to(before)>.05,"Speaking head turn/nod is applied to the real rig")
 check("Bhairavpur" in service.caption.text,"Correct arrival place")
 check(service.lantern.get_parent()==service.lantern_pivot,"Lantern remains attached to exterior hook")
 check(service.lantern_pivot.position.x>1.0,"Lantern is outside the cart side rail")
 var relative:Transform3D=cart.global_transform.affine_inverse()*service.lantern_pivot.global_transform
 cart.position+=Vector3(2,0,0);cart.rotation.y=.4
 await process_frame
 check((cart.global_transform.affine_inverse()*service.lantern_pivot.global_transform).origin.distance_to(relative.origin)<.00001,"Exterior mounting follows cart motion without floating")
 if not output.is_empty() and DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output.path_join("passenger_cart.png"))
 var player:CharacterBody3D=load("res://player/player.tscn").instantiate();world.add_child(player);player.position=cart.to_global(Vector3(1.7,0,2.4));player.set_physics_process(false)
 service._cache_world()
 check(service.clock==clock and service.viewer==player,"Clock and viewer caches belong to the fixture world")
 player.position+=Vector3(300,0,0)
 await create_timer(1.1).timeout
 var passenger:Node=service.passengers[0]
 check(is_equal_approx(passenger.simulation_interval,.5),"Remote passenger uses shared simulation tier")
 cart.position+=Vector3(.5,0,0)
 await physics_frame
 var pelvis:Vector3=passenger.actor._skeleton.to_global(passenger.actor._skeleton.get_bone_global_pose(passenger.actor._skeleton.find_bone("pelvis")).origin)
 check(pelvis.distance_to(passenger.socket.global_position+Vector3.UP*.11)<.02,"Seated contact follows the cart between remote pose updates")
 cart.set_meta("opening_cart_passage",true)
 await physics_frame
 check(is_zero_approx(passenger.simulation_interval),"Cinematic passenger updates remain full rate remotely")
 cart.remove_meta("opening_cart_passage")
 player.position=cart.to_global(Vector3(1.7,0,2.4))
 await physics_frame
 check(is_zero_approx(passenger.simulation_interval),"Approach immediately restores full-rate passenger pose")
 check(passenger.actor.body_collider.collision_layer==2,"Remote tiers retain passenger collision")
 for frame in 3:await physics_frame
 check(cart.board_at(player,"PublicPassenger_0_Right","passenger"),"Player boards a free passenger seat")
 var boarding_start:=Time.get_ticks_msec()
 while cart.boarding.transition!="" and Time.get_ticks_msec()-boarding_start<30000:await physics_frame
 check(cart.boarding.transition=="" and cart.boarding.rider==player,"Passenger boarding animation completes")
 for frame in 3:await process_frame
 check(cart.boarding.travel.menu!=null,"Passenger destinations appear after boarding")
 check(driver.visible,"Boarding as passenger does not hide the driver")
 print("PUBLIC PASSENGER CART ",JSON.stringify({"passed":errors.is_empty(),"errors":errors,"seats":cart.seat_sockets.size(),"npc_passengers":cart.get_meta("npc_occupied_seats",[]).size(),"dialogue":service.caption.text}))
 world.queue_free()
 for frame in 3:await process_frame
 quit(0 if errors.is_empty() else 1)
