extends SceneTree
## Actual world census, doubled groups, saved identities, destinations and native frame budget.
var errors:Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok:bool,message:String) -> void:
 if not ok:errors.append(message)
func run() -> void:
 var saver:Node=root.get_node("SaveManager")
 saver.start_new_game();await scene_changed
 for frame in 4:await process_frame
 var world:Node3D=current_scene
 var city:Node=world.get_node("CityRoutePopulation")
 var expansion:Node=world.get_node("PopulationExpansion")
 var exhaustive:bool="--exhaustive" in OS.get_cmdline_user_args()
 city.eager_population=exhaustive;expansion.eager_population=exhaustive
 var opening:Node=world.get_node("OpeningSequence")
 opening.morning();opening._release()
 paused=false
 var player:Node3D=world.get_node("Player");player.set_physics_process(false)
 player.global_position=Vector3(-389,world.layout.height(-389,321)+.9,321)
 var camera:Camera3D=world.get_node("SurveyCamera")
 camera.global_position=Vector3(-381,13,334);camera.look_at(Vector3(-390,8.2,320));camera.current=true
 var clock:Node=world.get_node("GameTimeSystem");clock.current_hour=10;clock.total_game_minutes=600;clock.clock_paused=true;clock._update_readable_time(true)
 var start:=Time.get_ticks_msec()
 var notice:=start+30000
 while (not city.ready_population or not expansion.census_finished or city.pedestrians.size()<20 or (exhaustive and not expansion.pending.is_empty())) and Time.get_ticks_msec()-start<300000:
  await process_frame
  if Time.get_ticks_msec()>=notice:
   notice+=30000
   print("POPULATION EXPANSION loading | city=",city.pedestrians.size()," logical=",city.pending.size()," counterparts=",expansion.materialized_count," originals=",expansion.discovered_count," pending=",expansion.pending.size())
 var expected:=0
 for count in city.ROUTE_COUNTS.values():expected+=int(count)*city.POPULATION_MULTIPLIER
 check(city.export_route_state().size()==expected,"City civilian identities did not double")
 check(city.patrols.size()==city.POLICE_ROUTES.size()*2,"City police group did not double")
 check(city.carts.size()==city.CART_ROUTES.size()*2,"City cart group did not double")
 check(expansion.discovered_count>100,"Census missed non-city population groups")
 check(not exhaustive or expansion.pending.is_empty(),"Counterparts could not find supported spawn positions")
 check(expansion.materialized_count+expansion.pending.size()==expansion.discovered_count,"Non-city identities did not double")
 
 var keys:Dictionary={}
 for person:Node3D in expansion.pedestrians:
  var key:String=person.get_meta("counterpart_of")
  check(not keys.has(key),"Duplicate counterpart: "+key);keys[key]=true
  check(person.find_children("*","Skeleton3D",true,false).size()==1,"Missing or duplicate MPFB rig")
 if not city.ready_population or not expansion.census_finished:
  print("POPULATION EXPANSION ",JSON.stringify({"passed":false,"stage":"population readiness timeout","city_loaded":city.pedestrians.size(),"city_pending":city.pending.size(),"non_city_originals":expansion.discovered_count,"counterparts_loaded":expansion.materialized_count,"counterparts_pending":expansion.pending.size(),"errors":errors}))
  saver.quit_game(1);return
 var original_state:Dictionary=expansion.export_route_state()
 check(original_state.size()>=expansion.discovered_count,"Save omitted expanded identities")
 expansion.advance_remote(1);expansion.restore_route_state(original_state)
 check(expansion.export_route_state()==original_state,"Expanded save roundtrip changed state")
 var origins:Dictionary={}
 for person:Node3D in city.pedestrians:origins[person]=person.get_node("CityStreetJourney").distance_walked
 var samples:Array[float]=[]
 var frame_start:=Time.get_ticks_usec()
 var moving:=0
 # Warm then measure at the actual 1280 x 720 populated-world budget.
 for frame in 20:await process_frame
 frame_start=Time.get_ticks_usec()
 if DisplayServer.get_name()!="headless":
  var arguments:PackedStringArray=OS.get_cmdline_args()
  var log_index:int=arguments.find("--log-file")
  if log_index>=0 and log_index+1<arguments.size():
   await RenderingServer.frame_post_draw
   var output:String=arguments[log_index+1].get_base_dir()
   root.get_texture().get_image().save_png(output.path_join("population_transient.png"))
 frame_start=Time.get_ticks_usec()
 var sample_start:=Time.get_ticks_msec()
 while samples.size()<120 or Time.get_ticks_msec()-sample_start<20000:
  await process_frame
  var now:=Time.get_ticks_usec();samples.append(float(now-frame_start)/1000);frame_start=now
 samples.sort()
 var cpu_ms:float=Performance.get_monitor(Performance.TIME_PROCESS)*1000
 var physics_ms:float=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
 var draws:int=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
 for person:Node3D in city.pedestrians:
  if person.get_node("CityStreetJourney").distance_walked-float(origins.get(person,person.get_node("CityStreetJourney").distance_walked))>.5:moving+=1
  check(person.global_position.is_finite(),"Invalid pedestrian transform")
 check(moving>origins.size()*.65,"Too few loaded city residents made progress")
 print("POPULATION PROFILE ",JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"resolution":root.size,"frames":samples.size(),"median_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*.95)],"last_process_ms":cpu_ms,"last_physics_ms":physics_ms,"draws":draws,"scope":"normal logical/materialised population at the actual 1280x720 world budget"}))
 print("POPULATION EXPANSION ",JSON.stringify({"passed":errors.is_empty(),"city_civilian_identities":city.export_route_state().size(),"city_walkers_loaded":city.pedestrians.size(),"city_police":city.patrols.size(),"city_carts":city.carts.size(),"non_city_originals":expansion.discovered_count,"counterpart_identities":expansion.materialized_count+expansion.pending.size(),"counterparts_loaded":expansion.materialized_count,"initial_walkers":origins.size(),"moving_city_walkers":moving,"conversations":world.get_node("PopulationSocial").conversations_started,"pending":expansion.pending.size(),"unresolved":expansion.unresolved,"errors":errors}))
 saver.quit_game(0 if errors.is_empty() else 1)
