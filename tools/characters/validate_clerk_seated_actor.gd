extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var errors:Array[String]=[]
 var document:=GLTFDocument.new();var state:=GLTFState.new()
 if document.append_from_file(ProjectSettings.globalize_path("res://characters/npcs/review/record_clerk_seat.glb"),state)!=OK:quit(1);return
 var actor:=preload("res://characters/npcs/indian/purpose_seated_actor.gd").new()
 actor.add_child(document.generate_scene(state));root.add_child(actor);actor.set_process(false)
 await process_frame
 if not actor.seat_ready:errors.append("Seated AnimationTree not ready")
 if actor.get_node_or_null("Vitality")==null or actor.body_collider==null:errors.append("Gameplay components missing")
 var ankles:Dictionary={};var maximum_drift:=0.0
 var minimum_pelvis:=INF;var maximum_pelvis:=-INF
 for side in ["l","r"]:ankles[side]=actor._skeleton.get_bone_global_pose(actor._skeleton.find_bone("foot_"+side)).origin
 for seated in [false,true]:
  actor.request_seated(seated)
  for frame in 120:
   actor._set_animation(&"idle",1.0/60.0)
   var pelvis_y:float=actor._skeleton.get_bone_global_pose(actor._skeleton.find_bone("pelvis")).origin.y
   minimum_pelvis=minf(minimum_pelvis,pelvis_y);maximum_pelvis=maxf(maximum_pelvis,pelvis_y)
   for side in ["l","r"]:
    var ankle:Vector3=actor._skeleton.get_bone_global_pose(actor._skeleton.find_bone("foot_"+side)).origin
    maximum_drift=maxf(maximum_drift,ankle.distance_to(ankles[side]))
   for mesh:MeshInstance3D in actor.seat_cloth:
    var sum:=0.0
    for index in mesh.mesh.get_blend_shape_count():sum+=mesh.get_blend_shape_value(index)
    if absf(sum-1.0)>.0001:errors.append("Seat cloth weight sum differs from one")
  if absf(actor.seat_phase-(1.0 if seated else 0.0))>.0001:errors.append("Entry/exit duration differs from two seconds")
 if maximum_pelvis-minimum_pelvis<.15:errors.append("Seated pose does not rise during exit")
 if maximum_drift>.002:errors.append("Exported ankle drift exceeds 2mm")
 if actor.seat_cloth.size()!=4:errors.append("Foundation or outfit seat correctives missing")
 print("CLERK_SEATED_ACTOR ",JSON.stringify({"passed":errors.is_empty(),"errors":errors,"maximum_ankle_drift_m":maximum_drift,"pelvis_vertical_travel_m":maximum_pelvis-minimum_pelvis,"seat_cloth_meshes":actor.seat_cloth.size(),"scope":"actual stationary actor tree, exported entry/exit, cloth phase and gameplay components; cloth/furniture/visual checks separate"}))
 actor.free();quit(0 if errors.is_empty() else 1)
