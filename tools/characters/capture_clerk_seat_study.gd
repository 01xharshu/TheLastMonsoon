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
 var study_path:=OS.get_environment("TLM_SEAT_REVIEW_GLB")
 if study_path.is_empty():study_path=ProjectSettings.globalize_path("res://characters/npcs/review/record_clerk_seat.glb")
 if document.append_from_file(study_path,state)!=OK:quit(1);return
 var actor:=preload("res://characters/npcs/indian/purpose_seated_actor.gd").new()
 actor.add_child(document.generate_scene(state));scene.add_child(actor);actor.set_process(false);actor.rotation.y=PI;actor.position.z=.87
 if OS.get_environment("TLM_REVIEW_FOUNDATION")=="1":
  for cloth_mesh:MeshInstance3D in actor.seat_cloth:
   if str(cloth_mesh.name)!="Opaque fitted underwear foundation":cloth_mesh.visible=false
 var desk:=load("res://objects/household/sets/records_desk.tscn").instantiate() as Node3D;scene.add_child(desk)
 # Match the existing MerchantHouseholdOffice chair and table dimensions.
 desk.get_node("Stool").free()
 var seat:=Node3D.new();scene.add_child(seat);seat.position=Vector3(0,.51,.87)
 _piece(scene,Vector3(0,.45,.87),Vector3(.6,.12,.55))
 _piece(scene,Vector3(0,.86,1.12),Vector3(.6,.8,.1))
 for x in [-.23,.23]:
  for z in [.64,1.09]:_piece(scene,Vector3(x,.22,z),Vector3(.07,.46,.07))
 desk.position.z=.07
 var top:MeshInstance3D=desk.get_node("TableTop");top.position.y=.75;top.mesh=top.mesh.duplicate();top.mesh.size=Vector3(1.7,.14,.8)
 for prop_name in ["Folio","Letter","Lamp"]:desk.get_node(prop_name).position.y=.82
 var camera:Camera3D=scene.get_node("Camera");camera.position=Vector3(2.6,1.25,.7);camera.fov=42;camera.look_at(Vector3(0,.7,.65))
 var rig:Skeleton3D=actor._skeleton
 var report:Dictionary={"scope":"isolated entry/hold/reversed exit, office chair/table dimensions; cloth contact separate; no live integration approval","minimum_body_y":INF,"maximum_body_minimum_y":-INF}
 var expected_skin_gap:=float(OS.get_environment("TLM_SEAT_SKIN_GAP"))
 report["expected_skin_seat_gap_m"]=expected_skin_gap
 var ankle_start:Dictionary={}
 report["maximum_ankle_drift_m"]=0.0
 var folder:String=OS.get_environment("TLM_REVIEW_DIR")
 if folder.is_empty():folder=OS.get_environment("TMPDIR").path_join("tlm_clerk_seat_study")
 DirAccess.make_dir_recursive_absolute(folder)
 for warmup in 3:await process_frame
 RenderingServer.force_draw(false)
 var started_usec:=Time.get_ticks_usec()
 for frame in 360:
  var phase:float=clampf(float(frame)/60.0,0,1) if frame<300 else clampf(float(360-frame)/60.0,0,1)
  actor.seat_phase=phase;actor.seat_clock=float(frame)/30.0;actor._set_animation(&"idle",0.0)
  for side in ["l","r"]:
   var ankle:Vector3=rig.to_global(rig.get_bone_global_pose(rig.find_bone("foot_"+side)).origin)
   if frame==0:ankle_start[side]=ankle
   report.maximum_ankle_drift_m=maxf(report.maximum_ankle_drift_m,ankle.distance_to(ankle_start[side]))
  if frame%15==0:
   for value in preload("res://tools/characters/skinned_ground_audit.gd").bounds(actor,rig,"*export_full_body*").values():
    report.minimum_body_y=minf(report.minimum_body_y,value.minimum_y);report.maximum_body_minimum_y=maxf(report.maximum_body_minimum_y,value.minimum_y)
  if OS.get_environment("TLM_REVIEW_REALTIME")=="1":
   var remaining:=float(frame+1)/30.0-float(Time.get_ticks_usec()-started_usec)/1000000.0
   if remaining>0:await create_timer(remaining).timeout
  if frame==180:
   report["seat_contact"]=preload("res://tools/characters/clerk_seat_contacts.gd").measure(actor,rig,seat.global_position)
   report["cloth_support"]=preload("res://tools/characters/clerk_seat_contacts.gd").cloth_support(actor,rig,seat.global_position)
  await process_frame;RenderingServer.force_draw(false)
  if frame in [30,180,330]:viewport.get_texture().get_image().save_png(folder.path_join("%04d.png"%frame))
  if frame==180:
   var side_position:=camera.position
   camera.position=Vector3(2.2,1.35,-1.1);camera.look_at(Vector3(0,.7,.65));await process_frame;RenderingServer.force_draw(false)
   viewport.get_texture().get_image().save_png(folder.path_join("0180_front.png"))
   camera.position=side_position;camera.look_at(Vector3(0,.7,.65))
 report["elapsed_seconds"]=float(Time.get_ticks_usec()-started_usec)/1000000.0
 report["authored_duration_seconds"]=12.0
 report["passed"]=absf(report.minimum_body_y)<.002 and absf(report.maximum_body_minimum_y)<.002 and report.maximum_ankle_drift_m<.002 and absf(report.seat_contact.skin_seat_gap_m-expected_skin_gap)<.003 and report.cloth_support.passed
 print("CLERK_SEAT_STUDY ",JSON.stringify(report))
 print("CLERK_SEAT_OUTPUT ",folder)
 quit(0 if report.passed else 1)

func _piece(parent:Node3D,at:Vector3,size:Vector3) -> void:
 var piece:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size
 var material:=StandardMaterial3D.new();material.albedo_color=Color(.24,.13,.065);material.roughness=.92;mesh.material=material
 piece.mesh=mesh;piece.position=at;parent.add_child(piece)
