extends SceneTree
## Checks exported garment tracks in the actual independent runtime trees.
## Contact and realistic cloth motion require separate visual/geometry checks.
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var stage:=Node3D.new();root.add_child(stage)
 var errors:Array[String]=[]
 for slug in ["village_farmer","village_woman","village_fruit_seller","village_weaver_assistant"]:
  var actor:=Node3D.new();actor.set_script(load("res://characters/npcs/indian/indian_npc_candidate.gd"));actor.set("candidate_slug",slug);stage.add_child(actor);actor.set_process(false)
  var player:AnimationPlayer=actor.get("animation_player")
  if player==null:errors.append(slug+": no player");continue
  var garments:Array[MeshInstance3D]=[]
  var body_vertices:=0;var foundations:=0
  for mesh:MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
   if "export_full_body" in mesh.name:
    for surface in mesh.mesh.get_surface_count():body_vertices+=mesh.mesh.surface_get_array_len(surface)
   if mesh.name.begins_with("Foundation"):foundations+=1
   if mesh.mesh.get_blend_shape_count()>0 and mesh.mesh.get_blend_shape_name(0).begins_with("idle fit"):garments.append(mesh)
  if body_vertices<14000:errors.append(slug+": incomplete body export")
  if foundations<(2 if slug in ["village_woman","village_fruit_seller"] else 1):errors.append(slug+": foundation missing")
  if garments.size()<3:errors.append(slug+": missing fitted garments")
  for clip in ["idle","walk"]:
   var tracks:=0
   for track in player.get_animation(clip).get_track_count():
    if player.get_animation(clip).track_get_type(track)==Animation.TYPE_BLEND_SHAPE:tracks+=1
   if tracks==0:errors.append(slug+": no cloth animation in "+clip)
   var expected_length:=2.0 if clip=="idle" else 1.2
   if absf(player.get_animation(clip).length-expected_length)>.05:errors.append(slug+": changed clip duration "+clip)
  for walking in [false,true,false]:
   actor.set("walking",walking)
   for frame in 150:
    actor.call("step_motion",1.0/60)
    if frame<20:continue
    for mesh in garments:
     var total:=0.0;var active:=0.0
     for key in mesh.mesh.get_blend_shape_count():
      var value:=mesh.get_blend_shape_value(key);total+=value
      if mesh.mesh.get_blend_shape_name(key).begins_with("walk fit" if walking else "idle fit"):active+=value
     if absf(total-1.0)>.01 or active<.99:
      errors.append(slug+": cloth weight/clip synchronization failed");break
  print("VILLAGE_CLOTH_TRACKS ",slug," body_vertices=",body_vertices," foundations=",foundations," garments=",garments.size())
  stage.remove_child(actor);actor.free()
 print("VILLAGE_CLOTHING_RUNTIME ","PASS" if errors.is_empty() else "FAIL"," ",errors)
 quit(0 if errors.is_empty() else 1)
