extends SceneTree
var errors:Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
 print(("PASS " if ok else "FAIL ")+label)
 if not ok:errors.append(label)
func run() -> void:
 var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
 await physics_frame
 # Keep real world geometry/physics; advance only the draft fixture explicitly.
 world.process_mode=Node.PROCESS_MODE_DISABLED
 for frame in 24:await physics_frame
 var actor:CharacterBody3D=world.get_node("Player");actor.set_physics_process(false)
 var carts:=get_nodes_in_group("bullock_carts")
 check(carts.size()==2,"two bullock carts integrated into live world")
 var cart:Node3D=world.get_node("LiveCarts/RoadBullockFreight")
 var journey:Node=cart.get_node("RoadJourney");journey.set_physics_process(false)
 check(cart.oxen.size()==2 and cart.solvers.size()==2,"paired actual rigged cattle")
 var neck_top:float=-INF
 var skin:MeshInstance3D=cart.oxen[0].find_child("Continuous cow skin",true,false)
 for vertex:Vector3 in skin.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
  if absf(vertex.x)<.07 and absf(vertex.z+.88)<.03:neck_top=maxf(neck_top,vertex.y)
 var yoke:MeshInstance3D=cart.visual_root.get_node("DraughtYoke")
 var yoke_gap:float=yoke.position.y-.06-(neck_top-.025)
 check(yoke_gap>=0 and yoke_gap<.010,"yoke clears posed neck by less than 10mm")
 print("DRAFT_YOKE_GAP_M ",yoke_gap)

 check(cart.driver!=null and cart.driver.get_meta("human_source","").contains("village_farmer"),"complete existing MPFB driver source")
 check(cart.seat_sockets.has("DriverSeat") and cart.boarding.clearance_shapes[1].shape.size.x>2,"player seat and paired draft collision")
 check(cart.get_meta("draft_fast_speed")==2.4,"bullock pace distinct from horse gallop")
 var start:Vector3=cart.global_position
 for frame in 180:
  journey._physics_process(1.0/60.0)
  await physics_frame
 print("DRAFT_MOVE ",start," -> ",cart.global_position," blocked ",journey.blocked_seconds)
 for shape in cart.boarding.clearance_shapes:
  var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=shape.global_transform;query.exclude=cart.boarding._vehicle_exclusions();query.collision_mask=1
  var hits:=cart.get_world_3d().direct_space_state.intersect_shape(query,8)
  for hit in hits:print("DRAFT_BLOCK ",shape.position," ",hit.collider.get_path())
 check(cart.global_position.distance_to(start)>2.5,"continuous freight movement uses real road clearance")
 var travel_start:Vector3=cart.global_position
 for frame in 2400:journey._physics_process(1.0/60.0)
 check(cart.global_position.x>-387,"complete first freight leg stays clear")
 print("DRAFT_ROUTE_END ",cart.global_position," blocked ",journey.blocked_seconds)
 cart.set_meta("errand_cargo",true);var held:Vector3=cart.global_position
 for frame in 20:journey._physics_process(1.0/60.0)
 check(cart.global_position.distance_to(held)<.001,"freight waits while entrusted cargo is loaded")
 cart.remove_meta("errand_cargo")
 var states:Array=preload("res://vehicles/cart_save_state.gd").collect(world)
 cart.global_position+=Vector3(15,0,0);preload("res://vehicles/cart_save_state.gd").restore(world,states)
 check(cart.global_position.distance_to(held)<.01,"bullock cart participates in existing save restoration")
 var mud:Node=cart.get_node("MudClods");mud.set_physics_process(false)
 actor.global_position=cart.global_position+Vector3(0,1,4)
 # Find a real wet earth-road segment, then sample both grounded wheel positions.
 var wet_at:=Vector3.INF
 for x in range(-420,-300):
  if preload("res://vehicles/cart_mud_effects.gd").wet_strength(Vector2(x,230))>.9:wet_at=Vector3(x,world.layout.height(x,230),230);break
 check(wet_at.is_finite(),"visible wet-earth patch on village road")
 cart.global_position=wet_at;cart.rotation.y=-PI*.5;actor.global_position=wet_at+Vector3(0,1,4)
 mud.previous=cart.global_position-Vector3(.12,0,0);mud.elapsed=.1;mud._physics_process(.1)
 check(mud.active_emission and mud.wet_contacts==2,"moving cart throws mud from both actual grounded wheels")
 mud.previous=cart.global_position;mud.elapsed=.1;mud._physics_process(.1)
 check(not mud.active_emission,"stationary cart throws no mud")
 cart.global_position=Vector3(-450,world.layout.height(-450,200),200);actor.global_position=cart.global_position+Vector3.UP
 mud.previous=cart.global_position-Vector3(.12,0,0);mud.elapsed=.1;mud._physics_process(.1)
 check(not mud.active_emission,"off-road dry ground throws no wet mud")
 for solver in cart.solvers:
  check(solver.feet.size()==4 and solver.rig.find_bone("Body")>=0 and solver.rig.find_bone("Head")>=0,"rigged four-limb cattle deformation")
 var prior_phase:float=cart.draft_phase
 cart.rotation.y+=.1;cart.set_forward_motion(0,.1)
 check(cart.draft_phase!=prior_phase,"draft feet step during steering turns")
 var public_cart:Node3D=world.get_node("LiveCarts/VillageBullockCart")
 actor.global_position=public_cart.to_global(Vector3(-2,.95,1.3))
 public_cart.boarding.set_physics_process(false)
 check(public_cart.boarding.board_at(actor,"DriverSeat","driver"),"Arjun boards public bullock cart")
 for frame in 160:public_cart.boarding._physics_process(1.0/60.0)
 public_cart.driver._process(.016)
 check(public_cart.boarding.transition.is_empty() and not public_cart.driver.visible,"continuous driver transfer replaces NPC driver")
 Input.action_press("move_forward")
 for frame in 160:public_cart.boarding._physics_process(1.0/60.0)
 Input.action_release("move_forward")
 check(public_cart.boarding.speed>0 and public_cart.boarding.speed<=2.4,"player-driven draft acceleration respects cattle pace")
 check(public_cart.solvers[0].rig.global_transform.is_finite(),"draft skeleton remains finite through steering and driving")
 FileAccess.open("res://docs/world/bullock_mud_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":errors.is_empty(),"errors":errors,"scope":"actual world geometry/physics with unrelated routines frozen and draft stepped explicitly; bullock integration, source/yoke clearance, road motion, collision, saves, cargo pause, wet/idle/dry guards, player boarding/pace; native and full motion/cloth/performance approval separate"},"  ")+"\n")
 print("BULLOCK MUD ","PASS" if errors.is_empty() else "FAIL",errors);quit(0 if errors.is_empty() else 1)
