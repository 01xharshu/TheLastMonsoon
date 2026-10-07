extends RefCounted
## CPU-skinned rear pelvis surface for the isolated seated fixture only.
static func measure(actor:Node3D,rig:Skeleton3D,seat:Vector3) -> Dictionary:
 var pelvis_local:=actor.to_local(rig.to_global(rig.get_bone_global_pose(rig.find_bone("pelvis")).origin))
 var minimum:=INF;var samples:=0
 for node:MeshInstance3D in actor.find_children("*export_full_body*","MeshInstance3D",true,false):
  var palette:Array[Transform3D]=[];var is_pelvis:Array[bool]=[]
  for bind in node.skin.get_bind_count():
   var index:int=rig.find_bone(node.skin.get_bind_name(bind)) if node.skin.get_bind_name(bind)!=&"" else node.skin.get_bind_bone(bind)
   palette.append(rig.global_transform*rig.get_bone_global_pose(index)*node.skin.get_bind_pose(bind));is_pelvis.append(rig.get_bone_name(index)=="pelvis")
  for surface in node.mesh.get_surface_count():
   var arrays:Array=node.mesh.surface_get_arrays(surface)
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
   var slots:int=weights.size()/vertices.size()
   for vertex in vertices.size():
    var point:=Vector3.ZERO;var pelvis_weight:=0.0
    for slot in slots:
     var offset:=vertex*slots+slot;var weight:=weights[offset]
     if weight>0:
      point+=(palette[bones[offset]]*vertices[vertex])*weight
      if is_pelvis[bones[offset]]:pelvis_weight+=weight
    var local:=actor.to_local(point)
    if pelvis_weight>.5 and local.z<pelvis_local.z-.03 and local.y<pelvis_local.y and absf(local.x)<.21:
     samples+=1;minimum=minf(minimum,point.y)
 return {"rear_pelvis_samples":samples,"minimum_skin_y":minimum,"seat_y":seat.y,"skin_seat_gap_m":minimum-seat.y}
