extends "res://tools/characters/audit_village_runtime_contact.gd"
## Native 1x inspection of the imported candidate on the real street actor.
func _matrix_rows(t:Transform3D) -> Array:
 return [[t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x],[t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y],[t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z],[0,0,0,1]]
func _initialize() -> void: run.call_deferred()
func _write_surface(actor:Node3D,rig:Skeleton3D,slug:String,output:String,sample:int,label:String) -> void:
 var data:Dictionary={"role":slug,"walking":true,"sample":sample,"label":label,"body":[],"garments":[]}
 data["rest"]={};data["bones"]={};data["rig_world"]=_matrix_rows(rig.global_transform)
 for bone in rig.get_bone_count():
  data.rest[rig.get_bone_name(bone)]=_matrix_rows(rig.get_bone_global_rest(bone))
  data.bones[rig.get_bone_name(bone)]=_matrix_rows(rig.get_bone_global_pose(bone))
 var skinned_records:Array[Dictionary]=[]
 for node:MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
  var body:bool="MakeHuman_body_export_cutout" in str(node.name)
  var cloth:bool=str(node.name) in ["Opaque fitted bra and thong foundation","Street coherent cotton blouse and pallu","Street sari front pallu","Street sari back tail"]
  if not body and not cloth:continue
  for surface in node.mesh.get_surface_count():
   var points:=posed_points(node,rig,surface);var serialized:=[]
   for point in points:serialized.append([point.x,point.y,point.z])
   var arrays:=node.mesh.surface_get_arrays(surface)
   var record:Dictionary={"name":str(node.name),"vertices":serialized,"indices":arrays[Mesh.ARRAY_INDEX]}
   if body:
    var raw:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
    var winding:=1.0
    for triangle in range(0,ids.size(),3):
     var a:int=ids[triangle];var b:int=ids[triangle+1];var c:int=ids[triangle+2]
     var dot:float=(raw[b]-raw[a]).cross(raw[c]-raw[a]).dot(normals[a]+normals[b]+normals[c])
     if absf(dot)>.00000001:winding=signf(dot);break
    record["winding_sign"]=winding;data.body.append(record)
   else:data.garments.append(record)
   skinned_records.append({"node":node,"surface":surface,"record":record})
 if not actor.adult_body_secondary.entries.is_empty():
  var saved:Array[Vector3]=[]
  for entry:Dictionary in actor.adult_body_secondary.entries:
   saved.append(rig.get_bone_pose_position(entry.bone));rig.set_bone_pose_position(entry.bone,entry.neutral)
  rig.force_update_all_bone_transforms()
  for item:Dictionary in skinned_records:
   var baseline:=posed_points(item.node,rig,item.surface);var serialized:=[]
   for point in baseline:serialized.append([point.x,point.y,point.z])
   item.record["neutral_vertices"]=serialized
  for index in saved.size():rig.set_bone_pose_position(actor.adult_body_secondary.entries[index].bone,saved[index])
  rig.force_update_all_bone_transforms()
 for piece:Dictionary in actor.drape.pieces:
  var node:MeshInstance3D=piece.node;var points:PackedVector3Array=posed_points(node,rig,0) if node.skin!=null else node.get_meta("river_sari_points",PackedVector3Array());var serialized:=[]
  for point in points:
   var world:Vector3=point if node.skin!=null else node.to_global(point);serialized.append([world.x,world.y,world.z])
  data.garments.append({"name":str(node.name),"vertices":serialized,"indices":node.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]})
 var file:=FileAccess.open(output+"/realtime_%04d.json"%sample,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()

func run() -> void:
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var actor:=preload("res://characters/npcs/indian/indian_street_actor.gd").new()
 actor.movement_enabled=false;actor.movement_profile=&"female"
 actor.set_meta("sari_hem_height_m",.08)
 var arm_clearance:=OS.get_environment("TLM_CANDIDATE_ARM_CLEARANCE")
 if not arm_clearance.is_empty():actor.set_meta("sari_arm_clearance_rad",float(arm_clearance))
 actor.set_meta("sari_hem_radius_m",.205)
 actor.set_meta("sari_fold_depth_m",.008)
 actor.set_meta("sari_waist_clearance_m",0.0)
 if OS.get_environment("TLM_CANDIDATE_FIT_WAIST")=="1":actor.set_meta("sari_fit_body_waist",true)
 actor.ground_height=func(_x:float,_z:float)->float:return 0.0
 var slug:=OS.get_environment("TLM_CANDIDATE_ID")
 if slug.is_empty():slug="female_05"
 var scene:PackedScene=load("res://characters/npcs/indian_body_candidates/"+slug+".glb")
 if scene==null:push_error("candidate import missing");quit(1);return
 actor.add_child(scene.instantiate())
 var calibrated:=false
 for mesh:MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
  var fit:Dictionary=mesh.get_meta("extras",{})
  if int(fit.get("street_body_fit_version",0))==1:calibrated=true
 if not calibrated and arm_clearance.is_empty():actor.set_meta("sari_arm_clearance_rad",.12)
 world.add_child(actor);actor.set_process(false);actor.set_physics_process(false)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.23,.26,.29);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;world.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-20,0);world.add_child(light)
 var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.fov=40
 await process_frame;await process_frame
 var skeletons:=actor.find_children("*","Skeleton3D",true,false)
 var meshes:=actor.find_children("*","MeshInstance3D",true,false)
 actor._set_animation(&"idle",0.0)
 if actor.drape!=null:actor.drape.update()
 var names:=PackedStringArray();for mesh:MeshInstance3D in meshes:names.append(str(mesh.name))
 if OS.get_environment("TLM_FOUNDATION_ONLY")=="1":
  for mesh:MeshInstance3D in meshes:
   if str(mesh.name) in ["Street coherent cotton blouse and pallu","Street sari front pallu","Street sari back tail","Sari lower border","Wrapped sari lower drape"]:mesh.hide()
 if skeletons.is_empty() or actor.drape==null or actor.drape.pieces.is_empty():push_error("candidate rig or runtime sari missing");quit(1);return
 if OS.get_environment("TLM_STREET_SECONDARY")=="1" and actor.adult_body_secondary.entries.size()!=4:
  push_error("Expected four explicitly adult authored secondary bones");quit(1);return
 var output:=OS.get_environment("TLM_CANDIDATE_OUTPUT")
 var views:Dictionary={"front":Vector3(0,1.05,3.2),"side":Vector3(3.2,1.05,0),"back":Vector3(0,1.05,-3.2)}
 for label:String in views:
  camera.position=views[label];camera.look_at(Vector3(0,.9,0));await process_frame;RenderingServer.force_draw(false)
  root.get_texture().get_image().save_png(output+"/"+label+".png")
 camera.position=Vector3(.18,1.46,1.4);camera.look_at(Vector3(0,1.36,0));camera.fov=34
 await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png(output+"/face.png")
 camera.fov=40
 actor.travel_speed=1.0
 var rig:Skeleton3D=skeletons[0]
 for sample in 17:
  var walking:=sample>0
  actor._set_animation(&"walk" if walking else &"idle",.12 if walking else 0.0)
  rig.force_update_all_bone_transforms();actor.drape.update()
  var data:Dictionary={"role":slug,"walking":walking,"sample":sample,"label":"native street", "body":[],"garments":[]}
  data["rest"]={};data["bones"]={};data["rig_world"]=_matrix_rows(rig.global_transform)
  for bone in rig.get_bone_count():
   data.rest[rig.get_bone_name(bone)]=_matrix_rows(rig.get_bone_global_rest(bone))
   data.bones[rig.get_bone_name(bone)]=_matrix_rows(rig.get_bone_global_pose(bone))
  for node:MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
   if "MakeHuman_body_export_cutout" not in str(node.name):continue
   var arrays:=node.mesh.surface_get_arrays(0);var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
   var raw:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
   var sign_value:=1.0
   for t in range(0,ids.size(),3):
    var a:=ids[t];var b:=ids[t+1];var c:=ids[t+2];var dot:float=(raw[b]-raw[a]).cross(raw[c]-raw[a]).dot(normals[a]+normals[b]+normals[c])
    if absf(dot)>.00000001:sign_value=signf(dot);break
   var points:=posed_points(node,rig,0);var serialized:=[]
   for point in points:serialized.append([point.x,point.y,point.z])
   data.body.append({"name":str(node.name),"vertices":serialized,"indices":ids,"winding_sign":sign_value})
  if OS.get_environment("TLM_CANDIDATE_UPPER_CONTACT")=="1":
   for node:MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
    if str(node.name) not in ["Opaque fitted bra and thong foundation","Street coherent cotton blouse and pallu","Street sari front pallu","Street sari back tail"]:continue
    for surface in node.mesh.get_surface_count():
     var cloth_points:=posed_points(node,rig,surface);var serialized:=[]
     for point in cloth_points:serialized.append([point.x,point.y,point.z])
     var cloth_arrays:=node.mesh.surface_get_arrays(surface)
     data.garments.append({"name":str(node.name),"vertices":serialized,"indices":cloth_arrays[Mesh.ARRAY_INDEX]})
  for piece:Dictionary in actor.drape.pieces:
   var node:MeshInstance3D=piece.node;var points:PackedVector3Array=node.get_meta("river_sari_points",PackedVector3Array());var serialized:=[]
   for point in points:
    var world_point:=node.to_global(point);serialized.append([world_point.x,world_point.y,world_point.z])
   var arrays:=node.mesh.surface_get_arrays(0)
   data.garments.append({"name":str(node.name),"vertices":serialized,"indices":arrays[Mesh.ARRAY_INDEX]})
  if sample in [0,4,8,12,16]:
   camera.position=Vector3(0,1.05,3.2);camera.look_at(Vector3(0,.9,0));await process_frame;RenderingServer.force_draw(false)
   root.get_texture().get_image().save_png(output+"/pose_%02d.png"%sample)
   camera.position=Vector3(0,1.05,-3.2);camera.look_at(Vector3(0,.9,0));await process_frame;RenderingServer.force_draw(false)
   root.get_texture().get_image().save_png(output+"/back_pose_%02d.png"%sample)
  if data.body.is_empty():push_error("candidate full body mesh missing");quit(1);return
  var output_file:=FileAccess.open(output+"/surface_%02d.json"%sample,FileAccess.WRITE)
  output_file.store_string(JSON.stringify(data));output_file.close()
 if OS.get_environment("TLM_CANDIDATE_REALTIME_WALK")=="1":
  var run_review := OS.get_environment("TLM_STREET_RUN") == "1"
  if run_review:
   actor.travel_speed = 2.8
   # Centre the 8.4 m run around the fixture origin for skin precision.
   actor.position.z = -4.2
  actor.adult_body_secondary.reset();actor.foot_plant.clear()
  var stance_samples:=0;var flight_samples:=0;var max_ankle_error:=0.0
  var elapsed:=0.0;var captured:=0;var frames:=0;var previous:int=Time.get_ticks_usec()
  while elapsed<3.0:
   await process_frame
   var now:int=Time.get_ticks_usec();var delta:float=minf(float(now-previous)/1000000.0,.05);previous=now
   elapsed+=delta;frames+=1
   actor.global_position+=Vector3.BACK*actor.travel_speed*delta
   actor._set_animation(&"walk",delta);actor.drape.update()
   if run_review and actor.run_blend > .95:
    if actor.run_contact.active:
     stance_samples+=1
     var contact=actor.run_contact
     var ankle:Vector3=rig.to_global(rig.get_bone_global_pose(contact.legs[contact.planted_side][2]).origin)
     max_ankle_error=maxf(max_ankle_error,ankle.distance_to(contact.planted_world))
    else: flight_samples+=1
   if captured<4 and elapsed>=.4+.65*captured:
    _write_surface(actor,rig,slug,output,1000+captured,"actual-time street run" if run_review else "actual-time street walk")
    for side:String in ["front","back"]:
     camera.global_position=actor.global_position+Vector3(0,1.05,3.2 if side=="front" else -3.2)
     camera.look_at(actor.global_position+Vector3.UP*.9)
     await process_frame;RenderingServer.force_draw(false)
     root.get_texture().get_image().save_png(output+"/realtime_"+side+"_%02d.png"%captured)
    captured+=1;previous=Time.get_ticks_usec()
  if run_review:
   print("INDIAN_RUN_CONTACT ",JSON.stringify({"stance_samples":stance_samples,"flight_samples":flight_samples,"max_ankle_error_m":max_ankle_error}))
   if stance_samples==0 or flight_samples==0 or max_ankle_error>.002:push_error("Run stance contact failed");quit(1);return
  if run_review and actor.run_blend < .999: push_error("Run branch never reached full blend");quit(1);return
  for entry:Dictionary in actor.adult_body_secondary.entries:
   var parent:Transform3D=rig.get_bone_global_pose(entry.parent)
   var frame:Basis=rig.global_basis*parent.basis*Transform3D(entry.rest).basis
   if (frame*entry.spring.offset).length()>actor.adult_body_secondary.limit_m(entry)+.000001:
    push_error("Adult secondary exceeded authored world limit");quit(1);return
  var age_gate=preload("res://characters/npcs/adult_body_secondary_motion.gd").new()
  var unmarked:=Node3D.new();age_gate.configure(unmarked,rig);unmarked.free()
  if not age_gate.entries.is_empty():push_error("Unmarked actor passed adult gate");quit(1);return
  var stopping:=0.0;previous=Time.get_ticks_usec()
  while stopping<1.0:
   await process_frame
   var now:int=Time.get_ticks_usec();var delta:float=minf(float(now-previous)/1000000.0,.05);previous=now
   stopping+=delta;actor._set_animation(&"idle",delta);actor.drape.update()
  if run_review and actor.run_blend != 0.0: push_error("Run branch did not return to idle");quit(1);return
  var residual:=0.0
  for entry:Dictionary in actor.adult_body_secondary.entries:
   var parent:Transform3D=rig.get_bone_global_pose(entry.parent)
   var frame:Basis=rig.global_basis*parent.basis*Transform3D(entry.rest).basis
   residual=maxf(residual,(frame*entry.spring.offset).length())
  if residual>.00025:push_error("Secondary did not settle after stopping");quit(1);return
  actor.adult_body_secondary.update(.5)
  for entry:Dictionary in actor.adult_body_secondary.entries:
   if rig.get_bone_pose_position(entry.bone).distance_to(entry.neutral)>.000001:
    push_error("Remote gap did not reset secondary bone");quit(1);return
  print("INDIAN_SECONDARY_SAFETY ",JSON.stringify({"adult_gate":true,"world_limits":true,"remote_reset":true,"stop_residual_m":residual,"scope":"four-bone imported adult study"}))
  print("INDIAN_CANDIDATE_REALTIME ",JSON.stringify({"seconds":elapsed,"frames":frames,"views":captured,"secondary_bones":actor.adult_body_secondary.entries.size(),"peaks_m":actor.adult_body_secondary.peak_by_family,"scope":("single imported study, actual-time run" if run_review else "single imported study, actual-time walk")}))
 if OS.get_environment("TLM_CANDIDATE_REACTIONS")=="1":
  var combat:Node=actor.get_node("CombatMotion");combat.set_process(false)
  for action:String in ["hit","slap","fall"]:
   combat.state="";actor.set_meta("combat_action","");actor.animation_tree.set("parameters/combat/blend_amount",0.0)
   actor.update_combat_clothing("");actor._set_animation(&"idle",0.0)
   actor.set_meta("impact_context",{"point":actor.global_position+Vector3.UP,"direction":Vector3.BACK,"kind":"punch","strength":.7})
   combat.play(action);combat.set_process(false);combat._process(.28 if action!="fall" else .55)
   _write_surface(actor,rig,slug,output,2000 if action=="hit" else 2001 if action=="slap" else 2002,action)
   camera.global_position=actor.global_position+Vector3(2,1.4,2.7);camera.look_at(actor.global_position+Vector3.UP*.75)
   await process_frame;RenderingServer.force_draw(false)
   root.get_texture().get_image().save_png(output+"/reaction_"+action+".png")
  combat._process(.6)
  if combat.state!="down" or not actor.drape.fallen:push_error("Fall did not retain skinned lower garments");quit(1);return
  _write_surface(actor,rig,slug,output,2003,"down")
  camera.global_position=actor.global_position+Vector3(2,1.4,2.7);camera.look_at(actor.global_position+Vector3.UP*.3)
  await process_frame;RenderingServer.force_draw(false)
  root.get_texture().get_image().save_png(output+"/reaction_down.png")
  combat.play("rise");combat.set_process(false);combat._process(1.1)
  if actor.drape.fallen:push_error("Rise did not restore walking cloth");quit(1);return
  print("INDIAN_CANDIDATE_REACTIONS ",JSON.stringify({"hit":true,"slap":true,"fall":true,"down":true,"rise":true}))
 print("INDIAN_CANDIDATE_NATIVE ",JSON.stringify({"passed":true,"skeletons":skeletons.size(),"meshes":names,"drape_pieces":actor.drape.pieces.size(),"arm_clearance_rad":actor.get_meta("sari_arm_clearance_rad",0.0),"waist_fit":actor.get_meta("sari_fit_body_waist",false),"secondary_bones":actor.adult_body_secondary.entries.size(),"secondary_peaks_m":actor.adult_body_secondary.peak_by_family}));quit()
