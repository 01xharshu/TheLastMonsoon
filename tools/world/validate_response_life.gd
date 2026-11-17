extends "res://tools/world/validate_crime_perception.gd"
## Real MPFB duty walking and map states; crossing priorities before physics.
class FakeInquiry extends Node:
 var world:Node
 var stage:="punishment"
 var second_return_path:=PackedVector3Array()
class FakeDirector extends Node:
 var active:=false
func run() -> void:
 create_timer(90).timeout.connect(func():root.get_node("SaveManager").quit_game(2))
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var clock:=Node.new();clock.name="GameTimeSystem";world.add_child(clock)
 var player:=TestPlayer.new();player.name="Player";world.add_child(player);player.position=Vector3(0,0,10)
 var floor_body:=StaticBody3D.new();world.add_child(floor_body)
 var floor_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,1,100);floor_shape.shape=box;floor_shape.position.y=-.5;floor_body.add_child(floor_shape)
 var soldier:Node3D=load("res://characters/npcs/british/british_npc_actor.gd").new()
 soldier.add_child(load("res://characters/npcs/british/private_man.glb").instantiate());world.add_child(soldier)
 soldier.set_meta("concept_rank_or_post","private")
 var duty: Node=load("res://world/suryagarh/military_duty.gd").new();duty.points=PackedVector3Array([Vector3.ZERO,Vector3(0,0,8)]);soldier.add_child(duty)
 await sync()
 check(duty.encounters==null,"early military duty tolerates encounter owner not yet installed")
 var crime:Node3D=load("res://tools/world/police_movement_fixture.gd").new();crime.name="CombatEncounters";world.add_child(crime);crime.player=player
 await sync()
 check(duty.encounters==crime,"military duty discovers encounter owner after startup")
 crime.patrol_terrain={"rids":[floor_body.get_rid()]}
 var contacts: RefCounted=load("res://player/map_contacts.gd").new()
 check(contacts.sample(player)[0].color==contacts.NORMAL,"normal soldier has grey map contact")
 soldier.set_meta("police_engaged",true)
 check(contacts.sample(player)[0].color==contacts.HOSTILE,"engaged soldier turns red without waiting for registry refresh")
 soldier.set_meta("police_engaged",false)
 check(contacts.sample(player)[0].color==contacts.NORMAL,"stand-down immediately restores grey contact")
 await map_pixels(player,soldier)
 duty.set_physics_process(false)
 for frame in 420:
  duty._physics_process(1.0/60.0)
  await physics_frame
 check(duty.walked>4 and soldier.position.z>3,"real MPFB soldier physically walks assigned duty route")
 await station_guard_test(world,crime)
 var before:=soldier.position;soldier.movement_enabled=false
 for frame in 20:duty._physics_process(.1)
 check(soldier.position==before,"crime recruitment suspends autonomous duty movement")
 soldier.movement_enabled=true
 var approaching:=Node3D.new();world.add_child(approaching);approaching.position=Vector3(0,0,8)
 soldier.position=Vector3.ZERO;soldier.rotation.y=0;soldier.body_collider.force_update_transform()
 crime.traffic_carts.assign([approaching])
 var patrol:Dictionary={"actor":soldier,"mount":null}
 for frame in 360:
  crime.yield_patrol_to_traffic(patrol,1.0/60.0)
  await physics_frame
 check(absf(soldier.position.x)>2.8,"patrolling actor physically clears an approaching cart lane")
 approaching.position=Vector3(0,0,-12)
 check(not crime.yield_patrol_to_traffic(patrol,1.0/60.0),"patrol resumes after cart passes")
 approaching.position=Vector3(0,0,-3);soldier.position=Vector3.ZERO;soldier.body_collider.force_update_transform()
 check(crime.yield_patrol_to_traffic(patrol,1.0/60.0),"patrol clears cart's rear body and draught-team envelope")
 approaching.queue_free()
 soldier.set_meta("dead",true)
 check(contacts.sample(player).is_empty(),"dead actors disappear from contacts")
 var crossing: Script=load("res://world/suryagarh/cart_crossing.gd")
 var a:=Vector2(-12,0);var b:=Vector2(0,-12)
 check(not crossing.must_yield(a,Vector2.RIGHT,b,Vector2.DOWN,1,2) and crossing.must_yield(b,Vector2.DOWN,a,Vector2.RIGHT,2,1),"equal crossing arrivals choose exactly one right of way")
 check(crossing.must_yield(a,Vector2.RIGHT,Vector2(0,-3),Vector2.DOWN,1,2),"cart already entering crossing keeps priority")
 check(not crossing.must_yield(a,Vector2.RIGHT,Vector2(0,9),Vector2.DOWN,2,1),"crossing releases after vehicle and team clear")
 check(not crossing.must_yield(a,Vector2.RIGHT,b,Vector2.RIGHT,2,1),"parallel roads do not create false crossing waits")
 check(crossing.must_yield(a,Vector2.RIGHT,b,Vector2.DOWN,1,2,true),"player-controlled cart has crossing priority")
 soldier.position=Vector3(35,0,35);soldier.body_collider.force_update_transform()
 await crossing_physics(world,floor_body,soldier,crime)
 print("RESPONSE LIFE ",JSON.stringify({"checks":count,"failures":failures,"status":"PASS" if failures.is_empty() else "FAIL"}))
 root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)

func crossing_physics(world: Node3D, floor_body: StaticBody3D, soldier:Node3D, crime:Node3D) -> void:
 var carts: Array[Node3D]=[]
 var journeys: Array[Node]=[]
 preload("res://world/suryagarh/tree_trunk_collision.gd").register_terrain_support(world,floor_body)
 for index in 2:
  var cart: Node3D=load("res://vehicles/bullock_cart.gd").new()
  cart.name="CrossingCart"+str(index)
  cart.position=Vector3(-16,0,0) if index==0 else Vector3(0,0,-16)
  cart.rotation.y=-PI*.5 if index==0 else PI
  world.add_child(cart);cart.add_to_group("city_route_carts")
  carts.append(cart)
 for frame in 10:await process_frame
 for index in 2:
  var journey: Node=load("res://world/suryagarh/city_cart_journey.gd").new()
  journey.name="CityRoadJourney";journey.configure(carts[index])
  journey.route.assign([Vector2(-22,0),Vector2(22,0)] if index==0 else [Vector2(0,-22),Vector2(0,22)])
  # Production setup runs first, then exact intersecting lanes are set for this test.
  carts[index].add_child(journey);journey.set_physics_process(false)
  journey.traffic.assign(carts);journey.traffic_age=10000
  journeys.append(journey)
 carts[0].position=Vector3(-16,0,0);carts[1].position=Vector3(0,0,-16)
 carts[0].rotation.y=-PI*.5;carts[1].rotation.y=PI
 journeys[0].route.assign([Vector2(-22,0),Vector2(22,0)])
 journeys[1].route.assign([Vector2(0,-22),Vector2(0,22)])
 for cart in carts:cart.boarding.collision_body.force_update_transform()
 await sync()
 var yielded:=false
 var closest:=INF
 for frame in 1800:
  if carts[0].position.x>12:journeys[0].wait=1000
  if carts[1].position.z>12:journeys[1].wait=1000
  for journey in journeys:
   journey._physics_process(.05)
   yielded=yielded or journey.crossing_yield
  closest=minf(closest,carts[0].position.distance_to(carts[1].position))
  await physics_frame
  if carts[0].position.x>9 and carts[1].position.z>9:break
 check(yielded,"actual boardable carts yield before perpendicular crossing")
 check(carts[0].position.x>9 and carts[1].position.z>9,"both actual carts clear crossing without deadlock")
 check(closest>4.0,"crossing retains physical cart separation")
 var second_reason:String=journeys[1].blocked_reason
 journeys[1].queue_free()
 await process_frame
 carts[0].position=Vector3(-12,0,0);carts[0].rotation.y=-PI*.5
 carts[1].position=Vector3(0,0,-12);carts[1].rotation.y=PI
 carts[1].boarding.rider=world.get_node("Player")
 carts[1].add_to_group("live_travel_carts")
 journeys[0].wait=0;journeys[0].retreat_remaining=0;journeys[0].passing_target=Vector2.INF
 journeys[0].traffic_age=0
 journeys[0]._physics_process(.1)
 check(journeys[0].crossing_yield,"city cart yields to player driving a non-city cart at crossing")
 carts[1].boarding.rider=null
 # Reproduce the real-world guard already inside a cart rear envelope.
 carts[0].position=Vector3.ZERO;carts[0].rotation.y=-PI*.5
 carts[0].boarding.collision_body.force_update_transform()
 soldier.set_meta("dead",false);soldier.position=Vector3(-3.2,0,-.23);soldier.body_collider.force_update_transform()
 var target:Vector3=soldier.position-carts[0].global_basis.x*4.0
 await sync()
 var lateral_before:float=absf(carts[0].to_local(soldier.position).x)
 var overlap_patrol:Dictionary={"actor":soldier,"mount":null,"traffic_yield_cart":weakref(carts[0]),"traffic_yield_target":target}
 var remote_start:Vector3=soldier.position
 crime.yield_patrol_to_traffic(overlap_patrol,.5)
 check(soldier.position.distance_to(remote_start)>.2,"remote overlap recovery uses accumulated time in swept steps")
 soldier.position=remote_start;soldier.body_collider.force_update_transform()
 await sync()
 var walking:Node=load("res://world/suryagarh/city_street_journey.gd").new()
 var route:Array[Vector2]=[Vector2(-3.2,0),Vector2(-3.2,-8)]
 walking.configure(soldier,route,0);walking.viewer=world.get_node("Player");soldier.add_child(walking);walking.set_physics_process(false)
 var pedestrian_start:Vector3=soldier.position
 check(walking.escape_cart_overlap(.5) and soldier.position.distance_to(pedestrian_start)>.2,"road pedestrian escapes an existing cart overlap with swept steps")
 walking.queue_free();soldier.position=pedestrian_start;soldier.body_collider.force_update_transform()
 await sync()
 var before_wrong:Vector3=soldier.position
 check(not crime.separate_patrol_from_cart(soldier,carts[0],soldier.position+carts[0].global_basis.x*4,.05) and soldier.position==before_wrong,"overlap recovery refuses movement through cart centre")
 var wall:=StaticBody3D.new();world.add_child(wall)
 wall.position=soldier.position-carts[0].global_basis.x*.35
 var wall_shape:=CollisionShape3D.new();var wall_box:=BoxShape3D.new();wall_box.size=Vector3(2,2,.1);wall_shape.shape=wall_box;wall_shape.position.y=1;wall.add_child(wall_shape)
 await sync()
 for frame in 20:
  crime.separate_patrol_from_cart(soldier,carts[0],target,.05)
  await physics_frame
 check(soldier.position.distance_to(before_wrong)<.1,"overlap recovery still respects an adjacent solid obstacle")
 wall.queue_free();soldier.position=before_wrong;soldier.body_collider.force_update_transform()
 await sync()
 var recovered:=false
 for frame in 240:
  recovered=crime.separate_patrol_from_cart(soldier,carts[0],target,.05) or recovered
  await physics_frame
  if absf(carts[0].to_local(soldier.position).x)>1.5:break
 check(recovered and absf(carts[0].to_local(soldier.position).x)>lateral_before+.5,"guard resolves existing cart overlap by moving outward")
 soldier.position=Vector3(35,0,35);soldier.body_collider.force_update_transform();soldier.set_meta("dead",true)
 print("CROSSING POSITIONS ",carts[0].position," ",carts[1].position," closest=",closest," reasons=",journeys[0].blocked_reason," / ",second_reason)

func map_pixels(player: CharacterBody3D, soldier: Node3D) -> void:
 if DisplayServer.get_name()=="headless":return
 var ui:=CanvasLayer.new();ui.name="UI";player.add_child(ui)
 var hud:=Control.new();hud.name="HUDRoot";hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.add_child(hud)
 var map: Control=load("res://player/world_map.gd").new();map.player=player;map.follow_story=false;ui.add_child(map)
 for frame in 12:await process_frame
 var radar: Control=map.minimap
 radar._refresh()
 await RenderingServer.frame_post_draw
 var at: Vector2=radar.point(Vector2(soldier.position.x,soldier.position.z),Vector2(player.position.x,player.position.z))
 var pixel: Vector2i=Vector2i(radar.get_global_transform_with_canvas()*at)
 var normal: Color=root.get_texture().get_image().get_pixelv(pixel)
 soldier.set_meta("police_engaged",true);radar._refresh()
 await process_frame
 await RenderingServer.frame_post_draw
 var hostile: Color=root.get_texture().get_image().get_pixelv(pixel)
 check(hostile.r>hostile.g*2 and absf(normal.r-normal.g)<.1,"native radar pixels switch from grey to red for engaged actor")
 soldier.set_meta("police_engaged",false)
 var output:=OS.get_environment("TLM_TUTORIAL_OUTPUT")
 if not output.is_empty():root.get_texture().get_image().save_png(output.path_join("response_radar.png"))

func station_guard_test(world:Node3D, crime:Node3D) -> void:
 var inquiry:=FakeInquiry.new();inquiry.world=world;world.add_child(inquiry)
 var director:=FakeDirector.new();director.name="DevStory";world.add_child(director)
 var guard:Node3D=load("res://story/dev_inquiry_guard.gd").new()
 guard.position=Vector3(20,0,0)
 guard.add_child(load("res://characters/npcs/british/private_man.glb").instantiate());world.add_child(guard)
 var duty:Node=load("res://world/suryagarh/military_duty.gd").new();duty.inquiry=inquiry
 duty.points=PackedVector3Array([guard.position,guard.position+Vector3(0,0,4)])
 guard.add_child(duty);duty.set_physics_process(false)
 await sync()
 check(not guard.movement_enabled,"station guard preserves thana's externally controlled movement mode")
 for frame in 20:duty._physics_process(.1)
 check(duty.walked==0,"station duty stays inactive before inquiry release")
 inquiry.stage="released"
 for frame in 300:
  duty._physics_process(1.0/60.0)
  await physics_frame
 check(duty.walked>2,"real inquiry guard walks when released despite thana movement mode")
 director.active=true
 var before:Vector3=guard.position
 for frame in 20:duty._physics_process(.1)
 check(guard.position==before,"active inquiry cinematic preempts station duty")
 director.active=false;guard.set_meta("external_combat_motion",true)
 for frame in 20:duty._physics_process(.1)
 check(guard.position==before,"crime pursuit ownership preempts station duty")
 guard.queue_free();inquiry.queue_free();director.queue_free()
 await sync()
