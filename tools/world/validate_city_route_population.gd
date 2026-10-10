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
 var opening:Node=world.get_node("OpeningSequence")
 var skip:=InputEventKey.new();skip.keycode=KEY_ESCAPE;skip.pressed=true
 opening._input(skip)
 for frame in 2:await process_frame
 opening._input(skip)
 var clock:Node=world.get_node("GameTimeSystem")
 clock.current_hour=10;clock.total_game_minutes=10*60;clock.clock_paused=true
 clock._update_readable_time(true)
 var player:Node3D=world.get_node("Player")
 player.set_physics_process(false)
 var start:=Time.get_ticks_msec()
 while not population.ready_population and Time.get_ticks_msec()-start<90000:
  await process_frame
 if not population.ready_population:
  print("CITY_POPULATION_RESULT ",JSON.stringify({"passed":false,"pending":population.pending.size(),"errors":["population did not finish spawning within 90 seconds"]}))
  root.get_node("SaveManager").quit_game(1)
  return
 paused=false
 population.set_process(false)
 var origins:Dictionary={};var route_counts:Dictionary={}
 for person:Node3D in population.pedestrians:
  origins[person]={"position":person.global_position,"walked":person.get_node("CityStreetJourney").distance_walked}
  var label:String=person.get_meta("population_route")
  route_counts[label]=int(route_counts.get(label,0))+1
 if population.pedestrians.size()!=72:errors.append("expected 72 extra walkers")
 if population.patrols.size()!=10:errors.append("expected 10 extra police patrols")
 if population.carts.size()!=8:errors.append("expected 8 extra carts")
 for label:String in population.ROUTE_COUNTS:
  if int(route_counts.get(label,0))!=population.ROUTE_COUNTS[label]:errors.append(label+": missing walkers")
 var cart_origins:Dictionary={};var police_origins:Dictionary={}
 for cart:Node3D in population.carts:cart_origins[cart]=cart.global_position
 for officer:Node3D in population.patrols:police_origins[officer]=officer.global_position
 await create_timer(16).timeout
 var moved:=0;var moving_routes:Dictionary={};var blocked:Dictionary={}
 for person:Node3D in population.pedestrians:
  # A completed return can finish near its origin; count actual swept travel.
  var distance:float=person.get_node("CityStreetJourney").distance_walked-float(origins[person].walked)
  var label:String=person.get_meta("population_route")
  if distance>1:
   moved+=1;moving_routes[label]=int(moving_routes.get(label,0))+1
  else:
   var journey:Node=person.get_node("CityStreetJourney")
   blocked[str(person.name)]={"distance":distance,"walked":journey.distance_walked,"obstacle":journey.last_obstacle,"blocked_frames":journey.blocked_frames,"action":person.get_meta("street_action",""),"position":str(person.global_position),"goal":journey.goal,"target":str(journey.route[journey.goal]),"wait":journey.wait,"clock_hour":journey.clock.current_hour if journey.clock!=null else -1}
  if not person.global_position.is_finite():errors.append(str(person.name)+": invalid position")
 for label:String in population.ROUTE_COUNTS:
  if int(moving_routes.get(label,0))<2:errors.append(label+": fewer than two walkers made progress")
 var moved_carts:=0;var stopped_carts:Array[String]=[]
 for cart:Node3D in population.carts:
  if cart.global_position.distance_to(cart_origins[cart])>2:moved_carts+=1
  else:
   var journey:Node=cart.get_node("CityRoadJourney")
   stopped_carts.append(str(cart.name)+" | at="+str(cart.global_position)+" goal="+str(journey.route[journey.direction])+" blocked="+str(journey.blocked_seconds)+" reason="+journey.blocked_reason+" wait="+str(journey.wait)+" can_move="+str(cart.can_move()))
 var moved_police:=0
 for officer:Node3D in population.patrols:
  if officer.global_position.distance_to(police_origins[officer])>1:moved_police+=1
 if moved!=72:errors.append("not all 72 walkers made progress")
 if moved_carts!=8:errors.append("not all eight carts made progress")
 if moved_police<8:errors.append("fewer than eight new police patrols made progress")
 print("CITY_POPULATION_RESULT ",JSON.stringify({"passed":errors.is_empty(),"people":population.pedestrians.size(),"police":population.patrols.size(),"carts":population.carts.size(),"moving_people":moved,"moving_police":moved_police,"moving_carts":moved_carts,"routes":moving_routes,"blocked_people":blocked,"stopped_carts":stopped_carts,"errors":errors}))
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
