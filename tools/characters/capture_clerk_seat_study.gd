extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var viewport:=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
 var preview:=TextureRect.new();preview.texture=viewport.get_texture();preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;root.add_child(preview)
 var scene:=load("res://characters/npcs/indian/purpose_npc_review.tscn").instantiate() as Node3D;viewport.add_child(scene)
 for role in ["dock_porter","boatman","record_clerk"]:scene.get_node(role).free();scene.get_node(role+"Label").free()
 var document:=GLTFDocument.new();var state:=GLTFState.new()
 if document.append_from_file(ProjectSettings.globalize_path("res://characters/npcs/review/record_clerk_seat.glb"),state)!=OK:quit(1);return
 var actor:=document.generate_scene(state);scene.add_child(actor);actor.rotation.y=PI;actor.position.z=.87
 var desk:=load("res://objects/household/sets/records_desk.tscn").instantiate() as Node3D;scene.add_child(desk)
 var camera:Camera3D=scene.get_node("Camera");camera.position=Vector3(2.1,1.3,2.1);camera.fov=42;camera.look_at(Vector3(0,.7,.65))
 var player:AnimationPlayer=actor.find_children("*","AnimationPlayer",true,false)[0]
 player.play("seat_entry");player.pause()
 var tree:=AnimationTree.new();actor.add_child(tree);tree.anim_player=tree.get_path_to(player)
 tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
 var graph:=AnimationNodeBlendTree.new();var pose:=AnimationNodeAnimation.new();pose.animation=&"seat_entry"
 graph.add_node("seated_entry",pose);graph.add_node("seat_seek",AnimationNodeTimeSeek.new());graph.connect_node("seat_seek",0,"seated_entry");graph.connect_node("output",0,"seat_seek")
 tree.tree_root=graph;tree.active=true
 var rig:Skeleton3D=actor.find_children("*","Skeleton3D",true,false)[0]
 var report:Dictionary={"scope":"isolated entry/hold/reversed exit, actual records desk/stool; cloth contact separate; no live integration approval","minimum_body_y":INF,"maximum_body_minimum_y":-INF}
 var folder:String=OS.get_environment("TLM_REVIEW_DIR")
 if folder.is_empty():folder=OS.get_environment("TMPDIR").path_join("tlm_clerk_seat_study")
 DirAccess.make_dir_recursive_absolute(folder)
 for frame in 180:
  var phase:float=clampf(float(frame)/60.0,0,1) if frame<120 else clampf(float(180-frame)/60.0,0,1)
  tree.set("parameters/seat_seek/seek_request",phase*player.get_animation("seat_entry").length);tree.advance(0.0)
  for mesh:MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
   if mesh.mesh==null:continue
   var samples:=0
   for index in mesh.mesh.get_blend_shape_count():
    if String(mesh.mesh.get_blend_shape_name(index)).begins_with("Seat cloth "):samples+=1
   if samples==0:continue
   var sample:=phase*float(samples-1);var first:=mini(int(sample),samples-1);var fraction:=sample-floorf(sample)
   for index in mesh.mesh.get_blend_shape_count():
    var name:String=mesh.mesh.get_blend_shape_name(index)
    var value:=0.0
    if name.begins_with("Seat cloth "):
     var number:=int(String(name).trim_prefix("Seat cloth "))
     value=1.0-fraction if number==first else fraction if number==mini(first+1,samples-1) else 0.0
    mesh.set_blend_shape_value(index,value)
  if frame%15==0:
   for value in preload("res://tools/characters/skinned_ground_audit.gd").bounds(actor,rig,"*export_full_body*").values():
    report.minimum_body_y=minf(report.minimum_body_y,value.minimum_y);report.maximum_body_minimum_y=maxf(report.maximum_body_minimum_y,value.minimum_y)
  if OS.get_environment("TLM_REVIEW_REALTIME")=="1":await create_timer(1.0/30.0).timeout
  if frame==90:report["seat_contact"]=preload("res://tools/characters/clerk_seat_contacts.gd").measure(actor,rig,desk.get_node("Stool/Seat").global_position)
  await process_frame;RenderingServer.force_draw(false)
  if frame in [30,90,150]:viewport.get_texture().get_image().save_png(folder.path_join("%04d.png"%frame))
 print("CLERK_SEAT_STUDY ",JSON.stringify(report))
 print("CLERK_SEAT_OUTPUT ",folder)
 quit()
