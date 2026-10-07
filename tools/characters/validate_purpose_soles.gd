extends SceneTree
## Deformed complete-body lowest surface on a flat floor; no terrain approval.
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var report:={"passed":true,"actors":{},"scope":"CPU-skinned full-body minimum height during idle/walk/stop on flat floor; not terrain or final motion approval"}
 for role in ["boatman","dock_porter","record_clerk"]:
  var actor:=Node3D.new()
  actor.set_script(load("res://characters/npcs/indian/indian_npc_candidate.gd"));actor.set("candidate_slug",role);root.add_child(actor);actor.set_process(false)
  var rig:=actor.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
  var minimum:=INF;var maximum:=-INF;var worst_frame:=-1;var stages:Dictionary={}
  for frame in 90:
   actor.set("walking",frame>=15 and frame<65);actor.call("step_motion",1.0/30)
   var bounds:Dictionary=preload("res://tools/characters/skinned_ground_audit.gd").bounds(actor,rig,"*export_full_body*")
   for value in bounds.values():
    if value.minimum_y<minimum:minimum=value.minimum_y;worst_frame=frame
    maximum=maxf(maximum,value.minimum_y)
    var stage:String="idle" if frame<15 or frame>=75 else "transition" if frame<25 or frame>=65 else "walk"
    if not stages.has(stage):stages[stage]={"minimum_y":INF,"maximum_y":-INF}
    stages[stage].minimum_y=minf(stages[stage].minimum_y,value.minimum_y)
    stages[stage].maximum_y=maxf(stages[stage].maximum_y,value.minimum_y)
  var passed:bool=minimum>=-.005 and maximum<=.008 and minimum<INF
  report.actors[role]={"minimum_surface_y_m":minimum,"maximum_lowest_surface_y_m":maximum,"passed":passed,"worst_frame":worst_frame,"stages":stages}
  report.passed=report.passed and passed
  actor.queue_free();await process_frame
 FileAccess.open("res://docs/characters/npcs/purpose_sole_contact.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("PURPOSE_SOLES ",JSON.stringify(report));quit(0 if report.passed else 1)
