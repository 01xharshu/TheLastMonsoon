extends SceneTree
const Policy=preload("res://world/suryagarh/settlement_police_routes.gd")
const Layout=preload("res://world/suryagarh/landscape_layout.gd")
const Density=preload("res://world/suryagarh/settlements/countryside_density.gd")
var failures:Array[String]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func frame_sample(label:String)->void:
 for frame in 10:await process_frame
 var values:Array[float]=[]
 var previous:=Time.get_ticks_usec()
 for frame in 40:
  await process_frame
  var now:=Time.get_ticks_usec();values.append(float(now-previous)/1000.0);previous=now
 values.sort()
 print("RURAL FRAME ",label," p50=",values[20],"ms p95=",values[38],"ms viewport=",root.size," scale=",root.scaling_3d_scale)
func run()->void:
 var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
 root.add_child(world);current_scene=world
 while world.get_node_or_null("RemoteMountains")==null:await process_frame
 while not world.get_node("RemoteMountains").ready_for_exploration:await process_frame
 var farms:Node3D=world.get_node("FarmBoundaries")
 check(farms.ready_for_exploration and farms.find_children("AdditionalField*","Node3D",false,false).size()==4,"four additional cultivated fields in normal world")
 check(farms.find_children("PlotTimber*","Node3D",false,false).size()==28,"28 open timber plot boundaries")
 var expansion:Node=world.get_node("PopulationExpansion")
 var policies_ok:=true
 for point:Vector2 in [Vector2(1000,-700),Vector2(570,-440),Vector2(800,-650),Vector2(460,-250),Vector2(-700,300)]:
  policies_ok=policies_ok and Policy.allows_route(expansion.nearest_route(point,true))
 check(policies_ok,"routine authority selects only inhabited streets from mountain/rural origins")
 check(not Policy.allows_route("fort_trail") and not Policy.allows_route("fort_access") and not Policy.allows_route("consignment_wilderness"),"mountain and wilderness routes excluded from routine duty")
 var migrated:Dictionary=expansion.safe_authority_save({"fort_trail:71":{"point":[800,-650],"health":13.0,"distance":42.0}},"village_spine:71",71,Vector2(-374,230),1)
 check(migrated.get("point")==[-374.0,230.0] and migrated.get("health")==13.0 and migrated.get("distance")==42.0,"legacy mountain patrol save repairs position and retains identity state")
 var live_ok:=true;var count:=0
 for actor in get_nodes_in_group("expanded_population_residents"):
  if actor.get_meta("combat_faction","") not in ["police","british"]:continue
  count+=1;live_ok=live_ok and Policy.allows_route(str(actor.get_meta("population_route","")))
 check(count>0 and live_ok,"live regional authority routine routes stay in settlements")
 var crime:Node3D=world.get_node("CombatEncounters")
 var region:Node3D=world.get_node("RemoteMountains")
 var start:Vector3=region.route[64];var goal:Vector3=region.route[66]
 var officer:Node3D=crime.spawn("MountainPursuitProbe","res://characters/npcs/thana/burkundaz_motion.glb",start,"police")
 officer.movement_enabled=false;officer.set_meta("external_combat_motion",true)
 officer.rotation.y=atan2(goal.x-start.x,goal.z-start.z)
 var pursuit:Dictionary={"actor":officer,"state":"pursue"}
 for frame in 200:
  await physics_frame
  if crime.navigate_patrol(pursuit,goal,2.8,1.0/60.0):break
 check(officer.global_position.distance_to(start)>1.0,"actual police pursuit navigation still advances on mountain trail")
 officer.queue_free()
 var player:CharacterBody3D=world.get_node("Player");player.set_physics_process(false);player.get_node("UI").hide()
 var terrain=preload("res://world/suryagarh/tree_trunk_collision.gd")
 var capsule:=CapsuleShape3D.new();capsule.radius=.65;capsule.height=1.8
 var blocked:=0
 # Test added collision specifically: existing roads/doors retain existing owners.
 var bodies:Array[RID]=[]
 for body:StaticBody3D in farms.find_children("*","StaticBody3D",true,false):bodies.append(body.get_rid())
 for lane:Array in Density.lanes():
  for i in lane.size()-1:
   var steps:=ceili(lane[i].distance_to(lane[i+1]))
   for j in range(steps+1):
    var p:Vector2=lane[i].lerp(lane[i+1],float(j)/maxi(1,steps))
    var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform.origin=farms.ground(p)+Vector3.UP*1.05
    var hits:=world.get_world_3d().direct_space_state.intersect_shape(query,32)
    for hit:Dictionary in hits:
     if hit.rid in bodies:blocked+=1
 check(blocked==0,"timber preserves full farm lane capsule clearance")
 var gates_clear:=true
 var centers:Array=Density.fields();centers.append_array(farms.NEW_FIELDS)
 for c:Vector2 in centers:
  var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform.origin=farms.ground(c+Vector2(21,0))+Vector3.UP*1.05
  for hit:Dictionary in world.get_world_3d().direct_space_state.intersect_shape(query,32):
   if hit.rid in bodies:gates_clear=false
 check(gates_clear,"all 28 eastern field access gaps remain open")
 # Actual ground on new plots must not be occupied by old tree/structure collision.
 var obstruction:=0
 var excluded:Array[RID]=terrain.terrain_exclusions(world);excluded.append(player.get_rid())
 var track_blockers:=0
 var cart_probe:=CapsuleShape3D.new();cart_probe.radius=1.25;cart_probe.height=2.5
 for lane:Array in Density.lanes().slice(0,6):
  for i in lane.size()-1:
   var steps:=ceili(lane[i].distance_to(lane[i+1])/1.5)
   for j in range(steps+1):
    var p:Vector2=lane[i].lerp(lane[i+1],float(j)/maxi(1,steps))
    var query:=PhysicsShapeQueryParameters3D.new();query.shape=cart_probe
    query.transform.origin=farms.ground(p)+Vector3.UP*1.28;query.exclude=excluded;query.collision_mask=1
    for hit:Dictionary in world.get_world_3d().direct_space_state.intersect_shape(query,8):
     if hit.collider is StaticBody3D:
      track_blockers+=1
      if track_blockers<8:print("RURAL TRACK BLOCK ",p," ",hit.collider.get_path())
 check(track_blockers==0,"new connecting tracks clear cart-width swept footprint against static structures and trunks")
 for c:Vector2 in farms.NEW_FIELDS:
  for offset:Vector2 in [Vector2.ZERO,Vector2(-12,-8),Vector2(12,-8),Vector2(-12,8),Vector2(12,8)]:
   var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform.origin=farms.ground(c+offset)+Vector3.UP*1.05;query.exclude=excluded
   var hits:=world.get_world_3d().direct_space_state.intersect_shape(query,8)
   if not hits.is_empty():obstruction+=1;print("RURAL FIELD BLOCK ",c+offset," ",hits[0].collider.get_path())
 check(obstruction==0,"new field interiors clear of existing solid structures/trees")
 # Genuine wet road + four-wheel coach, isolated from its autonomous driving.
 var cart:Node3D=load("res://vehicles/family_carriage_candidate.gd").new();world.add_child(cart)
 cart.boarding.set_physics_process(false)
 var mud:Node=load("res://vehicles/cart_mud_effects.gd").new();mud.name="MudClods";mud.configure(cart);cart.add_child(mud);mud.set_physics_process(false)
 var wet:=Vector2(-570,0)
 for z in range(-250,100):
  if mud.wet_strength(Vector2(-570,z))>.95:wet=Vector2(-570,z);break
 cart.global_position=farms.ground(wet);player.global_position=cart.global_position+Vector3(0,2,4)
 await physics_frame
 mud.previous=cart.global_position-Vector3(0,0,.2);mud.elapsed=.1;mud._physics_process(.1)
 var active:=0
 for splash:CPUParticles3D in mud.splashes:
  if splash.emitting:active+=1
 check(mud.particles.size()==cart.wheels.size() and active>0 and mud.active_emission,"real coach wheels disturb wet farm lane with clods and liquid splashes")
 mud.previous=cart.global_position;mud.elapsed=.1;mud._physics_process(.1)
 var still:=true
 for splash:CPUParticles3D in mud.splashes:still=still and not splash.emitting
 check(still and not mud.active_emission,"stationary coach stops mud disturbance")
 var output:=OS.get_environment("TLM_TUTORIAL_OUTPUT")
 if DisplayServer.get_name()!="headless" and output!="":
  var camera:=Camera3D.new();world.add_child(camera);camera.current=true
  for view:int in 2:
   var target:Vector3=farms.ground(Vector2(-632,326)) if view==0 else cart.global_position
   camera.global_position=target+Vector3(24,13,24) if view==0 else target+Vector3(4,2,5)
   camera.look_at(target+Vector3.UP*.4)
   if view==1:
    target=cart.wheels[-1].global_position-Vector3.UP*.7
    camera.global_position=target+Vector3(2.0,1.0,1.5);camera.look_at(target+Vector3.UP*.2)
   for frame in 20:
    if view==1:
     cart.global_position.z-=.04
     cart.global_position.y=farms.survey.height(cart.global_position.x,cart.global_position.z)
     mud.elapsed=.1;mud._physics_process(.02)
    await process_frame
   RenderingServer.force_draw(false);root.get_texture().get_image().save_png(output+"/rural_%d.png"%view)
   print("RURAL REVIEW ",output,"/rural_",view,".png")
   if view==0 and OS.get_environment("TLM_RURAL_PROFILE")=="1":
    root.scaling_3d_scale=1.0
    farms.visible=false;await frame_sample("farm-hidden")
    farms.visible=true;await frame_sample("farm-visible")
    farms.visible=false;await frame_sample("farm-hidden-repeat")
    farms.visible=true
   var deadline:=Time.get_ticks_msec()+45000
   while Time.get_ticks_msec()<deadline and not FileAccess.file_exists(output+"/rural_seen_%d"%view):await process_frame
 print("RURAL ROADS ","PASS" if failures.is_empty() else "FAIL",failures)
 await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures.is_empty() else 1)
