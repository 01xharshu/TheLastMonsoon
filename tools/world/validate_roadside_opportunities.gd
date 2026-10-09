extends SceneTree
var errors:Array=[]
var jobs:Node3D
var actor:CharacterBody3D
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
 print(("PASS " if ok else "FAIL ")+label)
 if not ok:errors.append(label)
func visit(endpoint:String) -> void:
 actor.global_position=jobs.targets[endpoint].global_position+Vector3(0,0,1.2);actor.velocity=Vector3.ZERO
 await physics_frame
func run() -> void:
 var world:=load("res://world/suryagarh/suryagarh_world.tscn").instantiate() as Node3D
 root.add_child(world);current_scene=world
 for frame in 25:await physics_frame
 jobs=world.get_node("ErrandSystem");actor=world.get_node("Player");actor.set_physics_process(false)
 var road:Node=jobs.roadside;road.set_physics_process(false);jobs.expanded.set_physics_process(false)
 check(jobs.targets.has("road_hospital"),"actual existing hospital receiver")
 for id in ["road_letter","road_office_bag","road_warehouse_crate","road_injured"]:
  check(jobs.JOBS.has(id),"catalogue "+id)
 actor.get_node("VisualRoot/CharacterVisual").equipment.stowed=true
 # Resolve this world-wired inventory after autoloads have started. Referencing
 # its global class while the standalone script loads compiles WorldAudio too early.
 var inv:Variant=actor.get_node("InventoryComponent");inv.items.erase("rupees")
 for id in ["road_letter","road_office_bag"]:
  road.locations[id]=Vector3(-245,7.2,225);road.location_days[id]=jobs.current_job_day();road._spawn(id)
  var endpoint:String=id+"_caller"
  jobs.source=endpoint;actor.global_position=Vector3(0,50,0)
  check(not jobs.accept(id),"remote offer rejected "+id)
  await visit(endpoint);check(jobs.accept(id),"caller accepts "+id)
  var goal:String=jobs.JOBS[id].goal
  await visit(goal);jobs.use_endpoint(goal,actor);jobs.close_panel()
  check(jobs.active==id,"cannot deliver before collection")
  await visit(endpoint);jobs.use_endpoint(endpoint,actor)
  check(jobs.stages[id]=="carrying","entrusted item collected")
  road._physics_process(.02);check(is_instance_valid(road.cargo),"actual carried item exists")
  var saved:Dictionary=jobs.export_state();jobs.restore_state(saved)
  check(jobs.active==id and jobs.stages[id]=="carrying" and road.locations.has(id),"save restores carried item and caller")
  var before:int=inv.get_item_count("rupees")
  await visit(goal);jobs.use_endpoint(goal,actor)
  check(jobs.active.is_empty() and inv.get_item_count("rupees")==before+jobs.JOBS[id].pay,"exact completion payment")
  jobs.use_endpoint(goal,actor);jobs.close_panel()
  check(inv.get_item_count("rupees")==before+jobs.JOBS[id].pay,"duplicate payment blocked")
  check(not jobs.job_available(id),"one payment this game day")
 # Loaded-cart consignment cannot be completed by walking to the receiver.
 road.locations.road_warehouse_crate=Vector3(-245,7.2,210);road._spawn("road_warehouse_crate")
 await visit("road_warehouse_crate_caller");jobs.source="road_warehouse_crate_caller";check(jobs.accept("road_warehouse_crate"),"crate request accepted")
 var freight:Node3D=jobs.expanded.borrowed;freight.global_position=Vector3(-247,7.2,210);freight.boarding.speed=0
 jobs.use_endpoint("road_warehouse_crate_caller",actor)
 check(jobs.stages.road_warehouse_crate=="carrying" and is_instance_valid(road.cargo_cart),"crate loaded onto actual stopped cart")
 if is_instance_valid(road.cargo_cart):freight=road.cargo_cart
 var loaded_position:Vector3=freight.global_position
 var cargo_save:Dictionary=jobs.export_state();freight.global_position+=Vector3(25,0,0);jobs.restore_state(cargo_save)
 check(road.cargo_cart==freight and freight.global_position.distance_to(loaded_position)<.01,"cargo cart position restored")
 await visit("port_cargo");jobs.use_endpoint("port_cargo",actor)
 check(jobs.active=="road_warehouse_crate" and inv.get_item_count("rupees")==18,"arrival without loaded cart pays nothing")
 freight.global_position=jobs.targets.port_cargo.global_position+Vector3(2,0,0);freight.boarding.speed=2;jobs.use_endpoint("port_cargo",actor)
 check(jobs.active=="road_warehouse_crate","moving loaded cart cannot deliver")
 freight.boarding.speed=0;jobs.use_endpoint("port_cargo",actor)
 check(jobs.active.is_empty() and inv.get_item_count("rupees")==34,"loaded crate exact wage")
 # Injured transfer reuses actual original passenger transfer, not a primitive NPC.
 road.locations.road_injured=Vector3(-245,7.2,210);road.location_days.road_injured=jobs.current_job_day();road._spawn("road_injured")
 await visit("road_injured_caller");jobs.source="road_injured_caller";check(jobs.accept("road_injured"),"injured caller accepted")
 var cart:Node3D=jobs.expanded.borrowed;cart.global_position=Vector3(-247,7.2,210)
 jobs.expanded.use_endpoint("road_injured_caller")
 check(jobs.expanded.transfer=="boarding","injured traveller begins actual boarding")
 for frame in 150:jobs.expanded._physics_process(1.0/60.0)
 check(jobs.expanded.seated and jobs.expanded.transfer.is_empty(),"injured passenger seated after continuous transfer")
 var state:Dictionary=jobs.export_state();jobs.restore_state(state)
 check(jobs.expanded.job_id=="road_injured" and jobs.expanded.seated,"injured cart/seat save restoration")
 jobs.cancel();check(not jobs.expanded.seated and inv.get_item_count("rupees")==34,"cancelled rescue pays nothing")
 # Hospital payment waits for stopped cart and the complete exit transfer.
 await visit("road_injured_caller");jobs.source="road_injured_caller";check(jobs.accept("road_injured"),"rescue can be accepted after cancellation")
 cart.global_position=jobs.targets.road_injured_caller.person.global_position+Vector3(-2,0,0)
 jobs.expanded.use_endpoint("road_injured_caller")
 for frame in 150:jobs.expanded._physics_process(1.0/60.0)
 await visit("road_hospital");jobs.use_endpoint("road_hospital",actor)
 check(inv.get_item_count("rupees")==34 and jobs.active=="road_injured","walking to hospital without passenger cart pays nothing")
 cart.global_position=jobs.targets.road_hospital.person.global_position+Vector3(-3,-.24,4);cart.boarding.speed=2
 jobs.use_endpoint("road_hospital",actor);check(jobs.expanded.transfer.is_empty(),"moving cart cannot unload patient")
 cart.boarding.speed=0
 for frame in 3:await physics_frame
 jobs.use_endpoint("road_hospital",actor)
 check(jobs.expanded.transfer=="exiting","hospital has clear actual passenger exit")
 check(inv.get_item_count("rupees")==34,"no wage before exit completion")
 for frame in 150:jobs.expanded._physics_process(1.0/60.0)
 check(not jobs.expanded.seated and jobs.active.is_empty() and inv.get_item_count("rupees")==58,"safe hospital arrival pays exact wage")
 # Original family job still binds its original actor after a rescue.
 jobs.source="office";await visit("office");check(jobs.accept("family_cart"),"original family job remains available")
 check(jobs.expanded.passenger==jobs.targets.passenger.person and jobs.expanded.job_id=="family_cart","original passenger ownership preserved")
 jobs.cancel()
 # Normal route discovery uses real ray/capsule ground tests and stays bounded.
 jobs.completed_days.clear();jobs.stages.clear()
 var discoveries:=0
 var points:PackedInt64Array=road.graph.get_point_ids()
 for fraction in [0.1,0.25,0.4,0.6,0.8]:
  for request in road.IDS:road._despawn(request)
  await physics_frame
  var at:Vector2=road.graph.get_point_position(points[int(points.size()*fraction)])
  actor.global_position=Vector3(at.x,world.layout.height(at.x,at.y),at.y)
  road.last_spawn=Vector3.INF;road.spawn_wait=0;road.tick=0
  road._physics_process(2.1)
  var live:=0
  for request in road.IDS:
   if jobs.targets.has(request+"_caller"):live+=1;discoveries+=1
  check(live<=2,"bounded route caller population")
 check(discoveries>=3,"road callers discovered across multiple route regions")
 print("ROADSIDE OPPORTUNITIES ","PASS" if errors.is_empty() else "FAIL",errors)
 await root.get_node("SaveManager").quit_game(0 if errors.is_empty() else 1)
