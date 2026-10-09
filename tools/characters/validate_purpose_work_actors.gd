extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var errors:Array=[]
 var report:Dictionary={"scope":"actual role actor authored clips, tree, collider, vitality, cloth interpolation and idle recovery; no world/fitting approval","actors":{},"errors":errors}
 for role in ["dock_porter","boatman","record_clerk"]:
  var actor:=preload("res://characters/npcs/indian/purpose_work_actor.gd").new()
  actor.purpose_role=role;actor.movement_enabled=false
  var document:=GLTFDocument.new();var state:=GLTFState.new()
  var path:String="res://characters/npcs/motion/%s/%s_rigged_candidate.glb"%[role,role]
  if document.append_from_file(ProjectSettings.globalize_path(path),state)!=OK:errors.append(role+": load failed");continue
  actor.add_child(document.generate_scene(state));root.add_child(actor);actor.set_process(false)
  if actor.animation_tree==null:errors.append(role+": tree missing");actor.free();continue
  if actor.get_node_or_null("BodyCollider")==null or actor.get_node_or_null("Vitality")==null:errors.append(role+": gameplay components missing")
  var idle:Animation=actor.animation_player.get_animation("idle")
  if absf(idle.length-8.0)>.001:errors.append(role+": role observation cycle missing")
  var head_motion:=false
  for track in idle.get_track_count():
   if idle.track_get_type(track)==Animation.TYPE_ROTATION_3D and String(idle.track_get_path(track).get_concatenated_subnames())=="head":
    head_motion=idle.rotation_track_interpolate(track,2.0).angle_to(idle.rotation_track_interpolate(track,6.0))>.03
  if not head_motion:errors.append(role+": head observation track missing")
  var walk:Animation=actor.animation_player.get_animation("walk")
  if absf(walk.length-1.2)>.001:errors.append(role+": authored gait replaced")
  actor._set_animation(&"idle",.83)
  actor.travel_speed=actor.nominal_walk_speed
  actor._set_animation(&"walk",.2)
  var skeleton:Skeleton3D=actor.get("_skeleton")
  var phase_ok:=false
  for track in walk.get_track_count():
   if walk.track_get_type(track)==Animation.TYPE_ROTATION_3D and String(walk.track_get_path(track).get_concatenated_subnames())=="thigh_l":
    var expected:Quaternion=walk.rotation_track_interpolate(track,fposmod(actor.purpose_phase,1.0)*walk.length)
    phase_ok=absf(expected.dot(skeleton.get_bone_pose_rotation(skeleton.find_bone("thigh_l"))))>.9999
  if not phase_ok:errors.append(role+": cloth/gait phase drift after idle")
  var shapes:=actor.purpose_cloth.size()
  if role=="boatman" and shapes<2:errors.append(role+": wrap targets missing")
  for frame in 90:actor._set_animation(&"walk",1.0/30.0)
  var peak:=0.0
  for mesh in actor.purpose_cloth:
   var sum:=0.0
   for index in mesh.mesh.get_blend_shape_count():sum+=mesh.get_blend_shape_value(index)
   if absf(sum-1.0)>.001:errors.append(role+": invalid cloth interpolation sum")
   peak=maxf(peak,sum)
  actor._set_animation(&"idle",.2)
  for mesh in actor.purpose_cloth:
   for index in mesh.mesh.get_blend_shape_count():
    if absf(mesh.get_blend_shape_value(index))>.0001:errors.append(role+": cloth did not return to idle")
  report.actors[role]={"role_idle_duration":idle.length,"head_observation":head_motion,"authored_walk_duration":walk.length,"cloth_gait_phase_aligned":phase_ok,"cloth_meshes":shapes,"corrective_weight_sum":peak,"nominal_speed":actor.nominal_walk_speed}
  actor.free()
 report["passed"]=errors.is_empty()
 print("PURPOSE_WORK_ACTORS ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
