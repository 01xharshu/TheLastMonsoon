extends "res://tools/characters/export_village_test_surfaces.gd"
## Load a temporary GLB through the real occupation actor and sample skin/morphs.
func capture_pose(_actor:Node3D,_label:String,_sample:int,_folder:String) -> void:
 pass
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.size()!=2:push_error("Temporary GLB and output directory required");quit(2);return
 var document:=GLTFDocument.new();var state:=GLTFState.new()
 state.use_named_skin_binds=true
 if document.append_from_file(args[0],state,GLTFDocument.IMPORT_FLAG_USE_NAMED_SKIN_BINDS)!=OK:quit(1);return
 var actor:=preload("res://characters/npcs/activity_actor.gd").new()
 var seat_height_text:=OS.get_environment("TLM_OCCUPATION_SEAT_HEIGHT")
 if not seat_height_text.is_empty():actor.seat_height=seat_height_text.to_float()
 var forward_text:=OS.get_environment("TLM_OCCUPATION_SEAT_FORWARD")
 if not forward_text.is_empty():actor.seat_foot_forward=forward_text.to_float()
 var yaw_text:=OS.get_environment("TLM_OCCUPATION_SEAT_YAW")
 if not yaw_text.is_empty():actor.seat_foot_yaw=deg_to_rad(yaw_text.to_float())
 var width_text:=OS.get_environment("TLM_OCCUPATION_SEAT_HALF_WIDTH")
 if not width_text.is_empty():actor.seat_foot_half_width=width_text.to_float()
 actor.add_child(document.generate_scene(state));root.add_child(actor);actor.set_process(false)
 await process_frame
 var rig:Skeleton3D=actor._skeleton
 assert(rig!=null)
 assert(not actor.seat_samples.is_empty(),"Fixture must activate the actual seat/ankle contact solver")
 print("OCCUPATION_NATIVE_SEAT_SAMPLES ",actor.seat_samples.size()," height=",actor.seat_height)
 var meshes:Array[MeshInstance3D]=[]
 for node:MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
  if node.skin!=null:meshes.append(node)
 var correctives:=preload("res://characters/npcs/occupation_cloth_correctives.gd").new()
 correctives.setup(actor)
 var cloth_count:=0;var foundation_count:=0;var body_count:=0
 for mesh in meshes:
  var label:=str(mesh.name)
  if label.contains("cotton") and label.contains("export"):
   assert(mesh.find_blend_shape_by_name("Study seated correction")>=0)
   assert(mesh.find_blend_shape_by_name("Study walk correction")>=0)
   cloth_count+=1
  if label.contains("opaque foundation"):
   assert(mesh.find_blend_shape_by_name("Study seated foundation")>=0);foundation_count+=1
  if label.contains("complete_MakeHuman_body"):
   body_count+=1
 assert(cloth_count==2 and foundation_count==1 and body_count==1)
 var moving_walk := OS.get_environment("TLM_OCCUPATION_MOVING_WALK")=="1"
 for label in ["idle","walk","repair","shape","read","write","rise"]:
  if label=="repair" and moving_walk:
   actor.global_position=Vector3.ZERO
   actor.travel_speed=0.0
  for sample in 17:
   if label=="walk":
    if moving_walk:
     actor.travel_speed=actor.nominal_walk_speed
     actor.global_position += actor.global_basis.z * actor.travel_speed * .08
    actor._set_animation(&"walk",.08)
    if moving_walk and sample>=3:assert(actor.foot_plant.active,"Moving walk must engage foot planting")
   elif label=="idle":actor._set_animation(&"idle",.08)
   else:actor.perform("idle" if label=="rise" else label,.08)
   actor.finish_contacts();correctives.update();rig.force_update_all_bone_transforms()
   if sample==16:print("OCCUPATION_NATIVE_BIND ",label," calves=",correctives.pitch("calf_l"),",",correctives.pitch("calf_r")," seat_error=",actor.get_meta("seat_error",-1)," ankle_error=",actor.get_meta("seated_ankle_error",-1))
   var data:Dictionary={"pose":label,"sample":sample,"meshes":[],"bones":[],"walk_phase":actor._walk_phase,"walk_blend":actor.locomotion_blend,"age":actor.activity_age,"planted":actor.foot_plant.active}
   var local_from_world := actor.global_transform.affine_inverse()
   for bone in rig.get_bone_count():
    var transform:=local_from_world*rig.global_transform*rig.get_bone_global_pose(bone)
    var rest_transform:=local_from_world*rig.global_transform*rig.get_bone_global_rest(bone)
    data.bones.append({"name":rig.get_bone_name(bone),"origin":[transform.origin.x,transform.origin.y,transform.origin.z],"basis":serialize_points(PackedVector3Array([transform.basis.x,transform.basis.y,transform.basis.z])),"rest_origin":[rest_transform.origin.x,rest_transform.origin.y,rest_transform.origin.z],"rest_basis":serialize_points(PackedVector3Array([rest_transform.basis.x,rest_transform.basis.y,rest_transform.basis.z]))})
   for node in meshes:
    if not (str(node.name).contains("complete_MakeHuman_body") or str(node.name).contains("cotton") or str(node.name).contains("opaque foundation")):continue
    for surface in node.mesh.get_surface_count():
     var arrays:=node.mesh.surface_get_arrays(surface)
     var morph_values:Dictionary={}
     for key in node.mesh.get_blend_shape_count():morph_values[str(node.mesh.get_blend_shape_name(key))]=node.get_blend_shape_value(key)
     var vertices := posed_points(node,rig,surface,local_from_world)
     data.meshes.append({"name":str(node.name),"vertices":serialize_points(vertices),"indices":arrays[Mesh.ARRAY_INDEX],"morphs":morph_values})
   var output:=FileAccess.open(args[1]+"/%s_%02d.json"%[label,sample],FileAccess.WRITE)
   output.store_string(JSON.stringify(data));output.close()
   await capture_pose(actor,label,sample,args[1])
 print("OCCUPATION_NATIVE_WALK_CONTACT_ENABLED ",moving_walk)
 print("OCCUPATION_NATIVE_SURFACES poses=119 cloth=2 foundation=1 body=1 morphs=preserved actual_activity_graph=true")
 actor.free();quit()
