extends SceneTree
## Probe actual station sentries after the inquiry releases ownership.
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
 root.add_child(world);current_scene=world
 var deadline:=Time.get_ticks_msec()+90000
 while (world.get_node_or_null("DevStory")==null or not world.get_node("DevStory").configured) and Time.get_ticks_msec()<deadline:await process_frame
 var story:Node=world.get_node("DevStory")
 var inquiry:Node=world.get_node("DevInquiry")
 var opening:Node=world.get_node_or_null("OpeningSequence")
 if opening!=null:opening.skip_cinematic()
 inquiry.stage="released";inquiry.return_started=true;inquiry.second_return_path.clear()
 story.active=false;story.player.set_meta("story_cinematic",false)
 var encounters:Node=world.get_node("CombatEncounters")
 var errors:Array[String]=[]
 for guard:Node3D in inquiry.guards:
  var duty:Node=guard.get_node("StationGuardDuty")
  var start:=guard.global_position
  var nav:Node=load("res://combat/police_search_navigation.gd").new();guard.add_child(nav)
  duty.set_physics_process(false)
  var initial_ground:Vector3=encounters.ground(start+Vector3(0,0,.05),false)
  var layout=load("res://world/suryagarh/landscape_layout.gd").new()
  var ground_query:=PhysicsRayQueryParameters3D.create(Vector3(start.x,layout.height(start.x,start.z)+4,start.z),Vector3(start.x,layout.height(start.x,start.z)-3,start.z),1)
  ground_query.exclude=encounters.ground_exclusions
  var ground_hit:=guard.get_world_3d().direct_space_state.intersect_ray(ground_query)
  print("SENTRY GROUND ",guard.name," ray=",initial_ground," collider=",str(ground_hit.collider.get_path()) if not ground_hit.is_empty() else "none")
  for frame in 2 if OS.get_environment("TLM_SENTRY_PROBE_ONLY")=="1" else 160:
   nav.move(encounters,guard,duty.points[1],1.1,.1)
   await physics_frame
  var body:CollisionShape3D=guard.body_collider.get_node("BodyShape")
  var query:=PhysicsShapeQueryParameters3D.new();query.shape=body.shape;query.collision_mask=1;query.exclude=[guard.body_collider.get_rid()]
  query.transform=body.global_transform;query.transform.origin+=Vector3(0,.025,.05)
  var labels:Array[String]=[]
  for hit in guard.get_world_3d().direct_space_state.intersect_shape(query,8):labels.append(str(hit.collider.get_path()))
  var support:float=load("res://world/suryagarh/settlements/station_floor_route.gd").support(guard,guard.global_position+Vector3(0,0,.05))
  var moved:=start.distance_to(guard.global_position)
  var next_point:=guard.global_position+Vector3(0,0,.05)
  var corrected:Vector3=encounters.patrol_ground(next_point,false,guard.body_collider.get_rid())
  var sweep:=PhysicsShapeQueryParameters3D.new();sweep.shape=body.shape;sweep.transform=body.global_transform;sweep.transform.origin+=Vector3.UP*.025;sweep.motion=corrected-guard.global_position;sweep.collision_mask=1
  var exclusions:Array[RID]=[guard.body_collider.get_rid()];exclusions.append_array(encounters.patrol_terrain.get("rids",[]));sweep.exclude=exclusions
  var sweep_result:=guard.get_world_3d().direct_space_state.cast_motion(sweep)
  for step in [.05,.12,.24,.4]:
   var point:=guard.global_position+Vector3(0,0,step)
   var floor_point:Vector3=encounters.patrol_ground(point,false,guard.body_collider.get_rid())
   var shape_query:=PhysicsShapeQueryParameters3D.new();shape_query.shape=body.shape;shape_query.transform=body.global_transform;shape_query.transform.origin+=Vector3(0,.025,step);shape_query.collision_mask=1;shape_query.exclude=[guard.body_collider.get_rid()]
   var obstacles:Array[String]=[]
   for hit in guard.get_world_3d().direct_space_state.intersect_shape(shape_query,8):obstacles.append(str(hit.collider.get_path()))
   print("SENTRY SAMPLE ",step," floor=",floor_point," hits=",obstacles)
  print("SENTRY STEP ",guard.name," grounded=",corrected," sweep=",sweep_result," in_station=",load("res://world/suryagarh/settlements/station_floor_route.gd").contains(inquiry.station,guard.global_position))
  print("SENTRY PROBE ",guard.name," moved=",moved," start=",start," target=",duty.points[1]," at=",guard.global_position," support=",support," hits=",labels," pending=",nav.pending," path=",nav.path," blocked=",nav.blocked_age)
  if moved<1:errors.append(str(guard.name))
  if OS.get_environment("TLM_SENTRY_FIRST_ONLY")=="1":break
 print("SENTRY RESULT ","PASS" if errors.is_empty() else "FAIL"," blocked=",errors)
 await load("res://tools/test_audio_cleanup.gd").finish(self,0 if errors.is_empty() else 1)
