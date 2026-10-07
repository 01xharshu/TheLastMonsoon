extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var world:=load("res://world/suryagarh/suryagarh_world.tscn").instantiate() as Node3D
 root.add_child(world);current_scene=world
 for frame in 25:await physics_frame
 var jobs:=world.get_node("ErrandSystem")
 var report:Dictionary={"passed":true,"actors":{},"scope":"stationary complete-body lowest surface versus collision ground in actual city; moving terrain and visual acceptance separate"}
 for endpoint in ["office","port_cargo","money_receiver"]:
  var actor:Node3D=jobs.targets[endpoint].person
  var rig:Skeleton3D=actor.get("_skeleton")
  var minimum:=INF
  for value in preload("res://tools/characters/skinned_ground_audit.gd").bounds(actor,rig,"*export_full_body*").values():minimum=minf(minimum,value.minimum_y)
  var query:=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.2,actor.global_position-Vector3.UP*.5,1)
  query.exclude=[actor.get_node("BodyCollider").get_rid(),jobs.targets[endpoint].get_rid()]
  var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
  var gap:float=minimum-hit.position.y if not hit.is_empty() else INF
  var passed:bool=gap>=-.005 and gap<=.008
  report.actors[actor.get_meta("purpose_role") ]={"position":str(actor.global_position),"minimum_body_y":minimum,"ground_y":hit.get("position",Vector3.INF).y,"gap_m":gap,"collider":str(hit.get("collider","missing")),"passed":passed}
  report.passed=report.passed and passed
 FileAccess.open("res://docs/characters/npcs/purpose_city_ground.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("PURPOSE_CITY_GROUND ",JSON.stringify(report));quit(0 if report.passed else 1)
