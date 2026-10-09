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

static func cloth_support(actor:Node3D,rig:Skeleton3D,seat:Vector3) -> Dictionary:
 var pelvis:=actor.to_local(rig.to_global(rig.get_bone_global_pose(rig.find_bone("pelvis")).origin))
 var minimum:=INF;var count:=0
 for node:MeshInstance3D in actor.find_children("Clerk full length trousers","MeshInstance3D",true,false):
  var palette:Array[Transform3D]=[]
  for bind in node.skin.get_bind_count():
   var bone:=node.skin.get_bind_bone(bind)
   if bone<0:bone=rig.find_bone(node.skin.get_bind_name(bind))
   palette.append(rig.global_transform*rig.get_bone_global_pose(bone)*node.skin.get_bind_pose(bind))
  for surface in node.mesh.get_surface_count():
   var arrays:=node.mesh.surface_get_arrays(surface)
   var positions:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var base:=positions.duplicate()
   var morphs:=node.mesh.surface_get_blend_shape_arrays(surface)
   for key in node.mesh.get_blend_shape_count():
    var amount:=node.get_blend_shape_value(key)
    if is_zero_approx(amount):continue
    var offsets:PackedVector3Array=morphs[key][Mesh.ARRAY_VERTEX]
    for index in positions.size():positions[index]+=(offsets[index] if node.mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_RELATIVE else offsets[index]-base[index])*amount
   var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
   var slots:int=weights.size()/positions.size()
   for index in positions.size():
    var point:=Vector3.ZERO
    for slot in slots:
     var offset:=index*slots+slot
     if weights[offset]>0:point+=(palette[bones[offset]]*positions[index])*weights[offset]
    var local:=actor.to_local(point)
    if absf(local.x)<.25 and local.z<pelvis.z-.03 and local.y<pelvis.y and point.y>seat.y-.08 and absf(point.z-seat.z)<.275:
     count+=1;minimum=minf(minimum,point.y)
 var gap:=minimum-seat.y
 return {"samples":count,"minimum_cloth_y":minimum,"cloth_seat_gap_m":gap,"passed":count>0 and gap>=-.002 and gap<=.006}
