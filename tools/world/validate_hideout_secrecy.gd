extends SceneTree
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const CityPopulation = preload("res://world/suryagarh/city_route_population.gd")
const RADIUS := 150.0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
 if not ok:failures.append(label);push_error(label)
func flat_distance(a:Vector3,b:Vector3) -> float:
 return Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))
func run() -> void:
 var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
 root.add_child(world);current_scene=world
 for frame in 120:await process_frame
 var player:CharacterBody3D=world.get_node("Player")
 var fort:Node3D=world.get_node("OldFort")
 var encounter:Node=fort.get_node("Gameplay/FortEncounter")
 var saves:Node=root.get_node("SaveManager")
 saves.save_root="user://hideout_secrecy"
 var continuing:=OS.get_environment("TLM_HIDEOUT_CONTINUE")=="1"
 if continuing:
  saves.pending_slot=2;saves.apply_pending(world)
  check(encounter.completed and encounter.chest.opened,"Continue restores collected fort supplies")
 else:
  # Old saves can still contain incomplete/dead garrison records.
  encounter.restore_state({"completed":false,"guards":[{"health":20},{"defeated":true}]})
  check(not encounter.completed and encounter.chest.interaction_available(),"legacy unfinished garrison save leaves supplies available")
 var center:Vector3=fort.to_global(Vector3(-56,0,48))
 var center2:=Vector2(center.x,center.z)
 # Every ordinary authored patrol route remains outside the hideout buffer,
 # including segments, not merely their endpoints.
 var layout:=Layout.new();var closest:=INF
 var routes:Array=CityPopulation.POLICE_ROUTES.duplicate()
 for route in ["police_to_compound","civil_lines_avenue","cantonment_approach"]:
  if route not in routes:routes.append(route)
 for label in routes:
  var points:Array=Layout.ROUTES[label]
  for i in range(points.size()-1):closest=minf(closest,layout.segment_distance(center2,points[i],points[i+1]))
 check(closest>=RADIUS+5,"authored routine patrol routes keep 150m buffer")
 var expansion:Node=world.get_node("PopulationExpansion")
 for route_points in Layout.ROUTES.values():
  for point:Vector2 in route_points:
   var selected:String=expansion.nearest_route(point,true)
   check(not selected.is_empty() and not expansion.route_near_hideout(Layout.ROUTES[selected]),"uniformed route selection is safe from every surveyed point")
 for name in ["fort_trail","fort_access"]:
  for point:Vector2 in Layout.ROUTES[name]:
   check(expansion.nearest_route(point) not in ["fort_trail","fort_access"],"civilian counterparts cannot select the private roads")
 var response:Node=world.get_node("CombatEncounters")
 check(response.private_fort(center) and not response.private_fort(fort.to_global(Vector3(0,0,105))),"secrecy boundary covers undercroft and leaves the scripted rescue approach outside")
 var authority:Node3D
 var counterpart_count:=0
 for actor in get_nodes_in_group("expanded_population_residents"):
  if not expansion.is_ancestor_of(actor) or actor.get_meta("combat_faction","") not in ["police","british"]:continue
  var journey:Node=actor.get_node("CityStreetJourney")
  check(not expansion.route_near_hideout(journey.route),"uniformed counterpart route keeps buffer")
  if authority==null:authority=actor
  counterpart_count+=1
 check(counterpart_count>0,"live regional police/British counterparts examined")
 if not continuing and authority!=null:
  var old_key:="fort_trail:%d"%int(authority.get_meta("population_index"))
  var old:Dictionary={old_key:{"point":[center.x,center.z],"goal":1,"health":13.0,"distance":42.0,"visits":3}}
  expansion.restore_route_state(old)
  for frame in 3:await process_frame
  check(flat_distance(authority.global_position,center)>=RADIUS,"legacy save cannot put uniformed counterpart at hideout")
  check(is_equal_approx(authority.get_node("Vitality").health,13.0) and is_equal_approx(authority.get_node("CityStreetJourney").distance_walked,42.0),"rerouted legacy counterpart keeps health and travel history")
 # Trigger the former garrison at the fort and around its undercroft, including
 # exact guard sites and the entrance; do not generate a wanted incident.
 player.set_physics_process(false)
 for local in [Vector3(0,1,45),Vector3(-8,1,22),Vector3(16,1,3),Vector3(-20,1,-16),Vector3(6,1,-35),Vector3(-56,1,48),Vector3(-56,4,72)]:
  player.global_position=fort.to_global(local)
  for frame in 8:await physics_frame
  encounter.activate()
  check(not encounter.activated and encounter.guards.is_empty(),"embedded fort never spawns garrison at "+str(local))
  for resident in get_nodes_in_group("expanded_population_residents"):
   if expansion.is_ancestor_of(resident):
    check(not response.private_fort(resident.global_position),"routine resident stays outside the private fort")
  for actor in get_nodes_in_group("combat_actors"):
   if world.is_ancestor_of(actor) and actor.get_meta("combat_faction","") in ["police","british"] and not actor.get_meta("dead",false):
    check(flat_distance(actor.global_position,center)>=RADIUS,"routine police or soldiers inside hideout buffer: "+str(actor.name))
 # Check a body-width route through a room opening and the west curtain breach.
 var capsule:=CapsuleShape3D.new();capsule.height=1.55;capsule.radius=.32
 var ignored:Array[RID]=preload("res://world/suryagarh/tree_trunk_collision.gd").terrain_exclusions(world)
 ignored.append(player.get_rid())
 for path in [[Vector2(-12,0),Vector2(-19,0)],[Vector2(-41,8.4),Vector2(-50,8.4)]]:
  var clear:=true
  for i in range(17):
   var p:Vector2=path[0].lerp(path[1],float(i)/16.0)
   var at:Vector3=fort.to_global(Vector3(p.x,0,p.y))
   var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1;query.exclude=ignored
   query.transform.origin=Vector3(at.x,layout.height(at.x,at.z)+.93,at.z)
   var hits:=world.get_world_3d().direct_space_state.intersect_shape(query,1)
   if not hits.is_empty():
    clear=false
    print("HIDEOUT SECRECY passage obstruction ",p," ",hits[0].collider.get_path())
    break
  check(clear,"body-width clearance through ruined fort opening "+str(path))
 if not continuing:
  player.global_position=encounter.chest.global_position+Vector3(0,.94,1.5)
  var prior:int=player.inventory.get_item_count("rupees")
  encounter.chest.interact(player)
  check(encounter.completed and player.inventory.get_item_count("rupees")==prior+26,"unguarded fort supplies pay once")
  encounter.chest.interact(player)
  check(player.inventory.get_item_count("rupees")==prior+26,"supply reward remains one-time")
  check(saves.save_game(world,2),"completed supply state saves to disk: "+saves.last_error)
 else:
  check(not encounter.chest.interaction_available(),"collected supplies remain unavailable on Continue")
 print("HIDEOUT SECRECY ","CONTINUE" if continuing else "NEW",": ","PASS" if failures.is_empty() else "FAIL", " nearest_routine_route=",closest,"m buffer=",RADIUS,"m counterparts=",counterpart_count)
 await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures.is_empty() else 1)
