extends SceneTree
func _initialize() -> void:
 call_deferred("run")
 create_timer(100).timeout.connect(func():quit(2))
func run() -> void:
 var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
 for body in world.find_children("*","CollisionObject3D",true,false):body.disable_mode=CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
 paused=true;PhysicsServer3D.set_active(true)
 await physics_frame
 world.process_mode=Node.PROCESS_MODE_DISABLED
 for i in 24:await physics_frame
 var cart:Node3D=world.get_node("LiveCarts/RoadBullockFreight")
 var actor:Node3D=world.get_node("Player")
 var mud:=preload("res://vehicles/cart_mud_effects.gd").new();mud.configure(cart);cart.add_child(mud);mud.set_physics_process(false)
 cart.rotation.y=-PI*.5
 for wet in [true,false]:
  var found:=false
  for x in range(-420,-300):
   var strength:float=mud.wet_strength(Vector2(x,230))
   if (wet and strength<.9) or (not wet and strength!=0):continue
   cart.global_position=Vector3(x,world.layout.height(x,230),230);actor.global_position=cart.global_position+Vector3(0,1,4)
   mud.previous=cart.global_position-Vector3(.2,0,0);mud.elapsed=.1;mud._physics_process(.1)
   if wet and mud.wet_contacts==2 and not mud.dust[0].emitting and not mud.dust[1].emitting:found=true;break
   if not wet and mud.wet_contacts==0 and (mud.dust[0].emitting or mud.dust[1].emitting):found=true;break
  if not found:push_error("Wheel effect failed for wet="+str(wet));quit(1);return
 mud.previous=cart.global_position;mud.elapsed=.1;mud._physics_process(.1)
 assert(not mud.active_emission and not mud.dust[0].emitting and not mud.dust[1].emitting)
 print("MAIN WORLD AIR: PASS | real wet/dry road contact, mud/dust exclusion, stopped cart silent")
 quit()
