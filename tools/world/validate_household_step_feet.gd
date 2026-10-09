extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 var errors:Array[String]=[];var worst:=0.0
 for file in ["households/merchant","households/landowner","british/official_woman"]:
  var actor:Node3D=load("res://characters/npcs/british/british_npc_actor.gd").new()
  actor.movement_profile=&"female" if "woman" in file else &"male";actor.foot_plant_enabled=false
  actor.add_child(load("res://characters/npcs/"+file+".glb").instantiate());root.add_child(actor);actor.set_process(false)
  var rig:Skeleton3D=actor.get("_skeleton")
  var journey:Node=load("res://world/suryagarh/settlements/household_resident_journey.gd").new();root.add_child(journey);journey.actor=actor
  for destination in [Vector3(0,.645,.5),Vector3(0,1.37,1.05),Vector3(0,.645,.5),Vector3.ZERO]:
   actor.call("_set_animation",&"idle",0)
   journey.transition_target=destination;journey.change("climb_step")
   for sample in 73:
    actor.call("_set_animation",&"idle",1.0/60)
    journey.elapsed=sample/60.0;journey._step_pose(1.2)
    var t:=sample/72.0
    for side in ["l","r"]:
     var foot:=rig.find_bone("foot_"+side)
     var target:Vector3=destination+actor.global_basis*(rig.transform*rig.get_bone_global_rest(foot).origin)
     var swing:float=smoothstep(0,.55,t) if side=="l" else smoothstep(.45,1,t)
     var expected:Vector3=journey.step_feet[side].lerp(target,swing)+Vector3.UP*(sin(swing*PI)*.08)
     worst=maxf(worst,rig.to_global(rig.get_bone_global_pose(foot).origin).distance_to(expected))
  if worst>.015:errors.append(file+": step ankle misses target")
  journey.queue_free();actor.queue_free();await process_frame
 print("HOUSEHOLD_STEP_FEET ",JSON.stringify({"passed":errors.is_empty(),"errors":errors,"max_ankle_error_m":worst,"scope":"actual resident rigs and production boarding leg solve; shoes/cloth mesh contact remain separate"}))
 quit(0 if errors.is_empty() else 1)
