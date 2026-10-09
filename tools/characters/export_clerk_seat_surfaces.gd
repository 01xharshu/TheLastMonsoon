extends "res://tools/characters/export_village_test_surfaces.gd"
## Actual imported seat skin/morph surfaces; caller owns temporary-file cleanup.
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.is_empty():push_error("Provide an OS temporary output directory");quit(2);return
 var folder:=args[0]
 var document:=GLTFDocument.new();var state:=GLTFState.new()
 var study_path:=OS.get_environment("TLM_SEAT_REVIEW_GLB")
 if study_path.is_empty():study_path=ProjectSettings.globalize_path("res://characters/npcs/review/record_clerk_seat.glb")
 if document.append_from_file(study_path,state)!=OK:quit(1);return
 var actor:=preload("res://characters/npcs/indian/purpose_seated_actor.gd").new()
 actor.add_child(document.generate_scene(state));root.add_child(actor);actor.set_process(false)
 await process_frame
 var rig:Skeleton3D=actor._skeleton
 var maximum_slots:=0
 var poses:=33
 for sample in poses:
  actor.seat_phase=float(sample)/float(poses-1);actor.seat_clock=float(sample)*8.0/float(poses-1);actor._set_animation(&"idle",0.0)
  rig.force_update_all_bone_transforms()
  var data:Dictionary={"role":"record_clerk_seat","walking":false,"sample":sample,"pelvis_y":rig.to_global(rig.get_bone_global_pose(rig.find_bone("pelvis")).origin).y,"body":[],"garments":[]}
  for node:MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
   if node.skin==null:continue
   var body:=str(node.name).contains("export_full_body")
   if not body and not actor.seat_cloth.has(node):continue
   for surface in node.mesh.get_surface_count():
    var arrays:=node.mesh.surface_get_arrays(surface)
    var raw:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
    maximum_slots=maxi(maximum_slots,weights.size()/raw.size())
    var entry:Dictionary={"name":str(node.name),"vertices":serialize_points(posed_points(node,rig,surface)),"indices":arrays[Mesh.ARRAY_INDEX]}
    entry["rest_vertices"]=serialize_points(raw)
    if body:
     var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
     for triangle in range(0,ids.size(),3):
      var a:=ids[triangle];var b:=ids[triangle+1];var c:=ids[triangle+2]
      var dot:float=(raw[b]-raw[a]).cross(raw[c]-raw[a]).dot(normals[a]+normals[b]+normals[c])
      if absf(dot)>.00000001:entry["winding_sign"]=signf(dot);break
    else:
     entry["active_keys"]=[]
     for key in node.mesh.get_blend_shape_count():
      var value:float=node.get_blend_shape_value(key)
      if value>.0001:entry.active_keys.append([node.mesh.get_blend_shape_name(key),value])
    data["body" if body else "garments"].append(entry)
  var output:=FileAccess.open(folder+"/clerk_%02d.json"%sample,FileAccess.WRITE)
  if output==null:push_error("Cannot write temporary surfaces");quit(2);return
  output.store_string(JSON.stringify(data));output.close()
 print("CLERK_NATIVE_SURFACES poses=33 maximum_skin_slots=",maximum_slots)
 actor.free();quit()
