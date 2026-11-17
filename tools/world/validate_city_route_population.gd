extends SceneTree
## Actual populated world and natural route movement; stdout only, no test artifacts.
var errors: Array[String] = []
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var saves:Node=root.get_node("SaveManager")
 saves.start_new_game()
 await scene_changed
 for frame in 4:await process_frame
 var world:Node3D=current_scene
 var population:Node=world.get_node("CityRoutePopulation")
 population.eager_population=true # Exhaustive fixture: materialise every logical identity.
 var opening:Node=world.get_node_or_null("OpeningSequence")
 var startup_deadline:=Time.get_ticks_msec()+120000
 while opening==null and Time.get_ticks_msec()<startup_deadline:
  await process_frame
  opening=world.get_node_or_null("OpeningSequence")
 if opening==null:
  push_error("New Journey did not create the opening sequence")
  saves.quit_game(1)
  return
 var skip:=InputEventKey.new();skip.keycode=KEY_ESCAPE;skip.pressed=true
 opening._input(skip)
 for frame in 2:await process_frame
 opening._input(skip)
 var clock:Node=world.get_node("GameTimeSystem")
 clock.current_hour=10;clock.total_game_minutes=10*60;clock.clock_paused=true
 clock._update_readable_time(true)
 var player:Node3D=world.get_node("Player")
 player.set_physics_process(false)
 print("CITY_POPULATION_PHASE spawning")
 var start:=Time.get_ticks_msec()
 while not population.ready_population and Time.get_ticks_msec()-start<180000:
  await process_frame
 if not population.ready_population:
  print("CITY_POPULATION_RESULT ",JSON.stringify({"passed":false,"pending":population.pending.size(),"errors":["population did not finish spawning within 180 seconds"]}))
  root.get_node("SaveManager").quit_game(1)
  return
 print("CITY_POPULATION_PHASE sampling people=",population.pedestrians.size()," police=",population.patrols.size()," carts=",population.carts.size())
 paused=false
 population.set_process(false)
 var duty_origins:Dictionary={}
 for duty in get_nodes_in_group("military_duties"):
  if duty.inquiry==null:duty_origins[duty]=duty.walked
 if duty_origins.size()!=7:errors.append("expected seven compound military duty actors")
 var origins:Dictionary={};var route_counts:Dictionary={};var skin_tones:Dictionary={}
 for person:Node3D in population.pedestrians:
  var tone:int=int(person.get_meta("population_skin_tone",-1))
  if tone<0:errors.append(str(person.name)+": missing textured skin variation")
  else:skin_tones[tone]=int(skin_tones.get(tone,0))+1
  origins[person]={"position":person.global_position,"walked":person.get_node("CityStreetJourney").distance_walked}
  var label:String=person.get_meta("population_route")
  route_counts[label]=int(route_counts.get(label,0))+1
 var expected_walkers:=0
 for count in population.ROUTE_COUNTS.values():expected_walkers+=int(count)*population.POPULATION_MULTIPLIER
 if population.pedestrians.size()!=expected_walkers:errors.append("missing authored walkers")
 if skin_tones.size()!=3:errors.append("street population is missing one or more individual skin tones")
 print("CITY_POPULATION_DENSITY_START ",density_summary(population.pedestrians))
 print("CITY_SKIN_TONES ",skin_tones)
 if population.patrols.size()!=population.POLICE_ROUTES.size()*population.POPULATION_MULTIPLIER:errors.append("incorrect doubled police count")
 if population.carts.size()!=population.CART_ROUTES.size()*population.POPULATION_MULTIPLIER:errors.append("incorrect doubled cart count")
 for label:String in population.ROUTE_COUNTS:
  if int(route_counts.get(label,0))!=population.ROUTE_COUNTS[label]*population.POPULATION_MULTIPLIER:errors.append(label+": missing walkers")
 var cart_origins:Dictionary={};var police_origins:Dictionary={}
 for cart:Node3D in population.carts:cart_origins[cart]=cart.get_node("CityRoadJourney").distance_travelled
 for officer:Node3D in population.patrols:police_origins[officer]=officer.global_position
 await create_timer(30).timeout
 print("CITY_POPULATION_DENSITY_AFTER_30S ",density_summary(population.pedestrians))
 var social_people:Array[Node3D]=[]
 for journey:Node in world.get_node("PopulationSocial").members:
  if is_instance_valid(journey) and is_instance_valid(journey.actor):social_people.append(journey.actor)
 print("CITY_POPULATION_DENSITY_ALL_REGISTERED ",density_summary(social_people)," count=",social_people.size())
 var moved:=0;var moving_routes:Dictionary={};var blocked:Dictionary={}
 for person:Node3D in population.pedestrians:
  # A completed return can finish near its origin; count actual swept travel.
  var distance:float=person.get_node("CityStreetJourney").distance_walked-float(origins[person].walked)
  var label:String=person.get_meta("population_route")
  if distance>1:
   moved+=1;moving_routes[label]=int(moving_routes.get(label,0))+1
  else:
   var journey:Node=person.get_node("CityStreetJourney")
   blocked[str(person.name)]={"distance":distance,"walked":journey.distance_walked,"obstacle":journey.last_obstacle,"blocked_frames":journey.blocked_frames,"action":person.get_meta("street_action",""),"position":str(person.global_position),"detour":str(journey.detour),"detour_followup":str(journey.detour_followup),"detours":journey.detours,"current_speed":journey.current_speed,"pace":journey.pace_scale,"goal":journey.goal,"target":str(journey.route[journey.goal]),"wait":journey.wait,"clock_hour":journey.clock.current_hour if journey.clock!=null else -1}
  if not person.global_position.is_finite():errors.append(str(person.name)+": invalid position")
 for label:String in population.ROUTE_COUNTS:
  if int(moving_routes.get(label,0))<2:errors.append(label+": fewer than two walkers made progress")
 var duty_progress:Dictionary={}
 for duty in duty_origins:
  var walked:float=duty.walked-float(duty_origins[duty])
  duty_progress[str(duty.actor.name)]={"walked":walked,"position":str(duty.actor.global_position),"target":str(duty.points[duty.index])}
  if walked<2:errors.append("military duty blocked: "+str(duty.actor.name))
 var moved_carts:=0;var stopped_carts:Array[String]=[]
 for cart:Node3D in population.carts:
  if cart.get_node("CityRoadJourney").distance_travelled-float(cart_origins[cart])>2:moved_carts+=1
  else:
   var journey:Node=cart.get_node("CityRoadJourney")
   stopped_carts.append(str(cart.name)+" | at="+str(cart.global_position)+" goal="+str(journey.route[journey.direction])+" blocked="+str(journey.blocked_seconds)+" reason="+journey.blocked_reason+" wait="+str(journey.wait)+" lane="+str(journey.road_lane)+" passing="+str(journey.passing_target)+" retreat="+str(journey.retreat_remaining)+" can_move="+str(cart.can_move()))
 var traffic_officers:Dictionary={}
 for record:Dictionary in world.get_node("CombatEncounters").patrols:
  if is_instance_valid(record.actor) and (str(record.actor.name).contains("cantonment_bazaar_lane_05") or record.has("traffic_yield_target")):
   traffic_officers[str(record.actor.name)]={"position":str(record.actor.global_position),"state":record.state,"yield_target":str(record.get("traffic_yield_target",Vector3.INF)),"speed":record.actor.travel_speed,"turning":record.actor.get_meta("patrol_turning",false),"mode":record.actor.get_meta("combat_action",""),"nav_blocked":record.navigation.blocked_age if record.has("navigation") else -1,"nav_pending":record.navigation.pending if record.has("navigation") else false,"nav_path":record.navigation.path.size() if record.has("navigation") else 0,"probe":patrol_probe(record,world.get_node("CombatEncounters"))}
 var moved_police:=0
 for officer:Node3D in population.patrols:
  if officer.global_position.distance_to(police_origins[officer])>1:moved_police+=1
 if moved!=expected_walkers:errors.append("not all authored walkers made progress")
 if moved_carts!=population.carts.size():errors.append("not all doubled carts made progress")
 if moved_police<int(population.patrols.size()*.8):errors.append("fewer than 80 percent of doubled patrols made progress")
 # Exercise the actual inquiry guard owners only after the story releases them.
 var inquiry:Node=world.get_node_or_null("DevInquiry")
 var director:Node=world.get_node_or_null("DevStory")
 var station_progress:Dictionary={}
 var station_duties:Array[Node]=[]
 for duty in get_nodes_in_group("military_duties"):
  if duty.inquiry!=null:station_duties.append(duty)
 if station_duties.size()!=4:errors.append("expected four inquiry guard duty actors")
 if inquiry!=null and director!=null and station_duties.size()==4:
  inquiry.stage="released";inquiry.return_started=true;inquiry.second_return_path.clear()
  director.active=false;player.set_meta("story_cinematic",false)
  var starts:Dictionary={}
  for duty in station_duties:starts[duty]=duty.walked
  await create_timer(15).timeout
  print("CITY_POPULATION_DENSITY_ALL_REGISTERED_45S ",density_summary(social_people))
  for duty in station_duties:
   var distance:float=duty.walked-float(starts[duty])
   station_progress[str(duty.actor.name)]={"walked":distance,"position":str(duty.actor.global_position),"target":str(duty.points[duty.index]),"duty_state":str(duty.actor.get("duty_state")),"external_motion":duty.actor.get_meta("external_combat_motion",false),"police_engaged":duty.actor.get_meta("police_engaged",false),"combat_action":duty.actor.get_meta("combat_action",""),"wait":duty.wait,"navigation":str(duty.navigation)}
   if distance<1:errors.append("station guard duty blocked: "+str(duty.actor.name))
 else:errors.append("inquiry duty owners not ready")
 print("CITY_POPULATION_RESULT ",JSON.stringify({"passed":errors.is_empty(),"people":population.pedestrians.size(),"police":population.patrols.size(),"carts":population.carts.size(),"military_duties":duty_progress,"station_duties":station_progress,"traffic_officers":traffic_officers,"moving_people":moved,"moving_police":moved_police,"moving_carts":moved_carts,"routes":moving_routes,"blocked_people":blocked,"stopped_carts":stopped_carts,"errors":errors}))
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--output=") and DisplayServer.get_name()!="headless":
   var cart:Node3D=population.carts[2]
   var camera:=Camera3D.new();world.add_child(camera)
   camera.global_position=cart.global_position+Vector3(8,5,7)
   camera.look_at(cart.global_position+Vector3.UP*1.4);camera.current=true
   for frame in 3:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(argument.trim_prefix("--output=").path_join("road_traffic.png"))
 root.get_node("SaveManager").quit_game(0 if errors.is_empty() else 1)

func patrol_probe(record:Dictionary, encounters:Node) -> Dictionary:
 var actor:Node3D=record.actor
 var goal:Vector3=record.get("traffic_yield_target",actor.global_position)
 var shape:CollisionShape3D=actor.body_collider.get_node("BodyShape")
 var offset:=goal-actor.global_position;offset.y=0
 if offset.length_squared()<.000001:return {}
 var next:Vector3=encounters.ground(actor.global_position+offset.normalized()*.05,actor.has_meta("population_route"))
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.collision_mask=1;query.margin=.002
 query.transform=shape.global_transform;query.transform.origin=next+Vector3.UP*(shape.position.y+.025)
 query.exclude=[actor.body_collider.get_rid()]
 var space:=actor.get_world_3d().direct_space_state
 var hits:Array=space.intersect_shape(query,8)
 var labels:Array[String]=[]
 for hit in hits:labels.append(str(hit.collider.get_path()))
 query.transform=shape.global_transform;query.transform.origin+=Vector3.UP*.025
 var sweep_exclusions:Array[RID]=[actor.body_collider.get_rid()]
 sweep_exclusions.append_array(encounters.patrol_terrain.get("rids",[]));query.exclude=sweep_exclusions
 query.motion=next-actor.global_position
 return {"ground":str(next),"yaw":actor.rotation.y,"hits":labels,"sweep":space.cast_motion(query)[0]}

func density_summary(people:Array) -> Dictionary:
 var max_neighbours:=0
 var busiest:Node3D
 var crowded:=0
 for person:Node3D in people:
  var count:=0
  for other:Node3D in people:
   if other!=person and absf(other.global_position.y-person.global_position.y)<2.0 and Vector2(other.global_position.x-person.global_position.x,other.global_position.z-person.global_position.z).length_squared()<36.0:count+=1
  if count>=5:crowded+=1
  if count>max_neighbours:max_neighbours=count;busiest=person
 var neighbours:Array[String]=[]
 var stationary:=0
 for person:Node3D in people:
  if str(person.get_meta("street_action","")) in ["yielding_to_traffic","waiting_for_clear_path","market_visit","home_pause"]:stationary+=1
 if busiest!=null:
  for other:Node3D in people:
   if other!=busiest and absf(other.global_position.y-busiest.global_position.y)<2.0 and Vector2(other.global_position.x-busiest.global_position.x,other.global_position.z-busiest.global_position.z).length_squared()<36.0:
    neighbours.append(str(other.name)+" "+str(other.global_position)+" "+str(other.get_meta("street_action","")))
 return {"neighbours":neighbours,"stationary_people":stationary,"max_neighbours_within_6m":max_neighbours,"people_with_5_or_more_neighbours":crowded,"busiest":str(busiest.name) if busiest!=null else "","position":str(busiest.global_position) if busiest!=null else ""}
