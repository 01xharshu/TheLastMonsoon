extends "res://tools/characters/audit_village_runtime_contact.gd"
## Disposable actual Godot skin/morph samples; the Python runner owns cleanup.
func serialize_points(points:PackedVector3Array) -> Array:
 var result:Array=[]
 for point in points:result.append([point.x,point.y,point.z])
 return result
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 if args.is_empty():push_error("Provide an OS temporary output directory");quit(2);return
 var folder:=args[0]
 var stage:=Node3D.new();root.add_child(stage)
 var roles: PackedStringArray = args.slice(1)
 if roles.is_empty(): roles = PackedStringArray(["village_farmer","village_woman","village_fruit_seller","village_weaver_assistant"])
 for slug in roles:
  var actor:=Node3D.new();actor.set_script(load("res://characters/npcs/indian/indian_npc_candidate.gd"));actor.set("candidate_slug",slug);stage.add_child(actor);actor.set_process(false)
  var rig:Skeleton3D=actor.find_children("*","Skeleton3D",true,false)[0]
  var count:=0
  for walking in [false,true,false]:
   actor.set("walking",walking)
   for sample in 12:
    actor.call("step_motion",.05 if sample<4 else .15);rig.force_update_all_bone_transforms()
    var data:Dictionary={"role":slug,"walking":walking,"sample":count,"body":[],"garments":[]}
    for node:MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
     if node.skin==null:continue
     var body:=str(node.name).contains("export_full_body")
     if not body and node.mesh.get_blend_shape_count()==0:continue
     for surface in node.mesh.get_surface_count():
      var arrays:=node.mesh.surface_get_arrays(surface)
      var entry:Dictionary={"name":str(node.name),"vertices":serialize_points(posed_points(node,rig,surface)),"indices":arrays[Mesh.ARRAY_INDEX]}
      if not body:
       entry["active_keys"] = []
       for key in node.mesh.get_blend_shape_count():
        var value: float = node.get_blend_shape_value(key)
        if value > .0001: entry["active_keys"].append([node.mesh.get_blend_shape_name(key), value])
      if body:
       var raw:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
       var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
       var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
       for triangle in range(0,ids.size(),3):
        var a:=ids[triangle];var b:=ids[triangle+1];var c:=ids[triangle+2]
        var cross:Vector3=(raw[b]-raw[a]).cross(raw[c]-raw[a])
        var dot:float=cross.dot(normals[a]+normals[b]+normals[c])
        if absf(dot)>.00000001:entry["winding_sign"]=signf(dot);break
      data["body" if body else "garments"].append(entry)
    var output:=FileAccess.open(folder+"/%s_%02d.json"%[slug,count],FileAccess.WRITE)
    if output==null:push_error("Cannot write temporary geometry");quit(2);return
    output.store_string(JSON.stringify(data));output.close();count+=1
  print("NATIVE_SURFACE_SAMPLES ",slug," ",count)
  stage.remove_child(actor);actor.free()
 quit()
