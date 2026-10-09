extends SceneTree
## Actual populated world and natural route movement; stdout only, no test artifacts.
var errors: Array[String] = []
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
 root.add_child(world);current_scene=world
 var population:Node=world.get_node("CityRoutePopulation")
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
  origins[person]=person.global_position
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
  var distance:float=person.global_position.distance_to(origins[person])
  var label:String=person.get_meta("population_route")
  if distance>1:
   moved+=1;moving_routes[label]=int(moving_routes.get(label,0))+1
  else:blocked[str(person.name)]={"distance":distance,"obstacle":person.get_node("CityStreetJourney").last_obstacle}
  if not person.global_position.is_finite():errors.append(str(person.name)+": invalid position")
 for label:String in population.ROUTE_COUNTS:
  if int(moving_routes.get(label,0))<2:errors.append(label+": fewer than two walkers made progress")
 var moved_carts:=0;var stopped_carts:Array[String]=[]
 for cart:Node3D in population.carts:
  if cart.global_position.distance_to(cart_origins[cart])>2:moved_carts+=1
  else:stopped_carts.append(str(cart.name))
 var moved_police:=0
 for officer:Node3D in population.patrols:
  if officer.global_position.distance_to(police_origins[officer])>1:moved_police+=1
 if moved<50:errors.append("fewer than 50/72 walkers made progress")
 if moved_carts<6:errors.append("fewer than six carts made progress")
 if moved_police<8:errors.append("fewer than eight new police patrols made progress")
 print("CITY_POPULATION_RESULT ",JSON.stringify({"passed":errors.is_empty(),"people":population.pedestrians.size(),"police":population.patrols.size(),"carts":population.carts.size(),"moving_people":moved,"moving_police":moved_police,"moving_carts":moved_carts,"routes":moving_routes,"blocked_people":blocked,"stopped_carts":stopped_carts,"errors":errors}))
 root.get_node("SaveManager").quit_game(0 if errors.is_empty() else 1)
