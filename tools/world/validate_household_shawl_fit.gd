extends SceneTree
const Surface=preload("res://tools/characters/village_contact_surface.gd")
func _initialize() -> void:call_deferred("_run")
func _posed(node:MeshInstance3D,rig:Skeleton3D) -> Dictionary:
 var points:=PackedVector3Array();var normals:=PackedVector3Array();var indices:=PackedInt32Array()
 var palette:Array[Transform3D]=[]
 for bind in node.skin.get_bind_count():
  var bone:int=rig.find_bone(node.skin.get_bind_name(bind)) if node.skin.get_bind_name(bind)!=&"" else node.skin.get_bind_bone(bind)
  palette.append(rig.global_transform*rig.get_bone_global_pose(bone)*node.skin.get_bind_pose(bind))
 for surface in node.mesh.get_surface_count():
  var a:Array=node.mesh.surface_get_arrays(surface)
  var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var n:PackedVector3Array=a[Mesh.ARRAY_NORMAL]
  var b:PackedInt32Array=a[Mesh.ARRAY_BONES];var w:PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS]
  var offset:=points.size();var slots:int=w.size()/v.size()
  for index in v.size():
   var p:=Vector3.ZERO;var normal:=Vector3.ZERO
   for slot in slots:
    var i:=index*slots+slot
    if w[i]>0:p+=(palette[b[i]]*v[index])*w[i];normal+=(palette[b[i]].basis*n[index])*w[i]
   points.append(p);normals.append(normal.normalized())
  for index in a[Mesh.ARRAY_INDEX]:indices.append(index+offset)
 return {"points":points,"normals":normals,"indices":indices}
func _run() -> void:
 var errors:Array[String]=[];var maximum:=0.0;var minimum:=INF;var samples:=0
 for role in ["merchant","landowner"]:
  var actor:Node3D=load("res://characters/npcs/british/british_npc_actor.gd").new();actor.foot_plant_enabled=false;actor.travel_speed=1.0
  var document:=GLTFDocument.new();var state:=GLTFState.new()
  document.append_from_file(ProjectSettings.globalize_path("res://characters/npcs/households/"+role+".glb"),state)
  actor.add_child(document.generate_scene(state));root.add_child(actor);actor.set_process(false)
  var rig:Skeleton3D=actor.get("_skeleton")
  var shirt:MeshInstance3D=actor.find_children("*Fitted cotton upper base*","MeshInstance3D",true,false)[0]
  var shawl:MeshInstance3D=actor.find_children("*Bordered shoulder shawl*","MeshInstance3D",true,false)[0]
  for pose in 12:
   actor.call("_set_animation",&"idle" if pose<4 else &"walk",.12)
   var base:=_posed(shirt,rig);var cloth:=_posed(shawl,rig)
   var surface:=Surface.new()
   for i in range(0,base.indices.size(),3):
    var a:Vector3=base.points[base.indices[i]];var b:Vector3=base.points[base.indices[i+1]];var c:Vector3=base.points[base.indices[i+2]]
    var normal:Vector3=(base.normals[base.indices[i]]+base.normals[base.indices[i+1]]+base.normals[base.indices[i+2]]).normalized()
    var low:=a.min(b).min(c);var high:=a.max(b).max(c);var id:=surface.triangles.size()
    surface.triangles.append({"a":a,"b":b,"c":c,"normal":normal,"low":low,"high":high})
    var first:=surface._cell(low);var last:=surface._cell(high)
    for x in range(first.x,last.x+1):
     for y in range(first.y,last.y+1):
      for z in range(first.z,last.z+1):
       var cell:=Vector3i(x,y,z)
       if not surface.cells.has(cell):surface.cells[cell]=[]
       surface.cells[cell].append(id)
   for point in cloth.points:
    var hit:=surface.nearest(point)
    if hit.is_empty():errors.append(role+": missing shirt contact surface");continue
    maximum=maxf(maximum,hit.distance);minimum=minf(minimum,hit.signed);samples+=1
  actor.queue_free();await process_frame
 if maximum>.015 or minimum<-.003:errors.append("shawl moving fit exceeds 15 mm gap / 3 mm penetration")
 print("HOUSEHOLD_SHAWL_CONTACT ",JSON.stringify({"passed":errors.is_empty(),"errors":errors,"samples":samples,"max_gap_m":maximum,"min_signed_clearance_m":minimum}))
 quit(0 if errors.is_empty() else 1)
