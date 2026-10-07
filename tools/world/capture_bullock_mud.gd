extends SceneTree
var viewport:SubViewport
var camera:Camera3D
var world:Node3D
var cart:Node3D
var folder:="res://docs/world/captures/bullock/"
func _initialize() -> void:run.call_deferred()
func shot(label:String,at:Vector3,target:Vector3) -> void:
 camera.global_position=at;camera.look_at(target)
 for frame in 6:await process_frame
 await RenderingServer.frame_post_draw
 viewport.get_texture().get_image().save_png(folder+label+".png");print("BULLOCK_CAPTURE ",label)
func run() -> void:
 root.size=Vector2i(960,540);root.disable_3d=true
 viewport=SubViewport.new();viewport.size=Vector2i(960,540);viewport.own_world_3d=false;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var display:=TextureRect.new();display.texture=viewport.get_texture();display.size=Vector2(960,540);display.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(display)
 world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
 for frame in 25:await physics_frame
 var player:CharacterBody3D=world.get_node("Player");player.set_physics_process(false);player.get_node("UI").hide();player.get_node("VisualRoot").hide();player.get_node("CameraPivot/SpringArm3D/Camera3D").set_process(false)
 world.get_node("GameTimeSystem").clock_paused=true
 camera=Camera3D.new();camera.fov=48;viewport.add_child(camera);camera.make_current()
 cart=world.get_node("LiveCarts/RoadBullockFreight");cart.get_node("RoadJourney").set_physics_process(false)
 player.global_position=cart.global_position+Vector3(0,1,6)
 cart.set_forward_motion(0,.016)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 await shot("paired_bullocks_driver",cart.to_global(Vector3(-5,2.8,-4)),cart.to_global(Vector3(0,1.1,.4)))
 await shot("yoke_and_hooves",cart.to_global(Vector3(-3,1.9,-3)),cart.to_global(Vector3(0,.85,-1.5)))
 var wet_at:=Vector3.INF
 for x in range(-416,-402):
  if preload("res://vehicles/cart_mud_effects.gd").wet_strength(Vector2(x,230))>.95:wet_at=Vector3(x,world.layout.height(x,230),230);break
 if not wet_at.is_finite():print("BULLOCK_CAPTURE FAIL no wet route point");quit(1);return
 cart.global_position=wet_at;cart.rotation.y=-PI*.5
 var motion:=cart.get_node("RoadJourney");motion.wait=0;motion.direction=1;cart.boarding.set_physics_process(false)
 motion.route.assign([Vector2(wet_at.x,wet_at.z),Vector2(wet_at.x+10,wet_at.z)])
 DirAccess.make_dir_recursive_absolute("/tmp/tlm_bullock_mud_motion")
 var mud:Node=cart.get_node("MudClods");mud.set_physics_process(false)
 var observed:=false
 var start:Vector3=cart.global_position
 for frame in 90:
  motion._physics_process(1.0/30.0);player.global_position=cart.global_position+Vector3(0,1,6)
  mud.elapsed=.1;mud._physics_process(1.0/30.0);observed=observed or mud.active_emission
  camera.global_position=cart.to_global(Vector3(-4,1.6,5));camera.look_at(cart.to_global(Vector3(0,.7,1.2)))
  await process_frame;await RenderingServer.frame_post_draw
  viewport.get_texture().get_image().save_png("/tmp/tlm_bullock_mud_motion/%04d.png"%frame)
  if frame==45:viewport.get_texture().get_image().save_png(folder+"moving_wet_road.png")
 print("BULLOCK_CAPTURE MUD_OBSERVED ",observed," movement_m ",cart.global_position.distance_to(start)," renderer ",RenderingServer.get_current_rendering_method())
 quit()
