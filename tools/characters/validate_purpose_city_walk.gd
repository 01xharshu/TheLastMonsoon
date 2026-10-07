extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var world:=load("res://world/suryagarh/suryagarh_world.tscn").instantiate() as Node3D
 root.add_child(world);current_scene=world
 for frame in 25:await physics_frame
 var jobs:=world.get_node("ErrandSystem")
 var report:Dictionary={"passed":true,"actors":{},"scope":"authored walking on short collision-ground paths at actual work stations; sampled lowest full-body surface, not terrain slope or production approval"}
 for endpoint in ["office","port_cargo","money_receiver"]:
  var actor:Node3D=jobs.targets[endpoint].person
  actor.set_process(false)
  var rig:Skeleton3D=actor.get("_skeleton")
  var start:=actor.global_position
  var excluded:Array[RID]=[actor.get_node("BodyCollider").get_rid(),jobs.targets[endpoint].get_rid()]
  var camera:Camera3D
  if DisplayServer.get_name()!="headless":
   camera=Camera3D.new();world.add_child(camera);camera.current=true;camera.fov=38
  var minimum:=INF;var maximum:=-INF;var missing:=0
  for frame in 45:
   actor.global_position=start+Vector3.FORWARD*float(frame)*float(actor.get("nominal_walk_speed"))/30.0
   var query:=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.4,actor.global_position-Vector3.UP*.6,1)
   query.exclude=excluded
   var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
   if hit.is_empty():missing+=1;continue
   actor.global_position.y=hit.position.y
   actor.call("_set_animation",&"walk",1.0/30)
   for value in preload("res://tools/characters/skinned_ground_audit.gd").bounds(actor,rig,"*export_full_body*").values():
    var point:Vector3=value.minimum_point
    query=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.4,point-Vector3.UP*.6,1);query.exclude=excluded
    hit=world.get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():missing+=1;continue
    var gap:float=point.y-hit.position.y
    minimum=minf(minimum,gap);maximum=maxf(maximum,gap)
   if camera!=null and frame==30:
    camera.global_position=actor.global_position+Vector3(2.2,1.5,2.5)
    camera.look_at(actor.global_position+Vector3.UP*.85)
    await process_frame
    RenderingServer.force_draw(false)
    root.get_texture().get_image().save_png("res://docs/characters/npcs/purpose_city_walk_"+str(actor.get_meta("purpose_role"))+".png")
  if camera!=null:camera.queue_free()
  var passed:=missing==0 and minimum>=-.005 and maximum<=.008
  report.actors[actor.get_meta("purpose_role")]={"minimum_gap_m":minimum,"maximum_gap_m":maximum,"missing_ground_samples":missing,"passed":passed}
  report.passed=report.passed and passed
  actor.global_position=start
 FileAccess.open("res://docs/characters/npcs/purpose_city_walk.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("PURPOSE_CITY_WALK ",JSON.stringify(report));quit(0 if report.passed else 1)
