extends RefCounted
## Body-derived seam anchors, sampled once at spawn; no body fitting in the frame loop.
static func anchors(actor:Node3D,rig:Skeleton3D,sides:int) -> Array[Vector3]:
 var pelvis:=rig.get_bone_global_pose(rig.find_bone("pelvis"))
 var hip:=actor.to_local(rig.to_global(pelvis.origin))
 var samples:Array[Vector3]=[]
 for node:MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
  var label:=node.name.to_lower()
  if node.skin==null or "foundation" in label or not ("makehuman_body" in label or "mpfb_body" in label):continue
  var palette:Array[Transform3D]=[];var torso:Array[bool]=[]
  for bind in node.skin.get_bind_count():
   var bone:int=rig.find_bone(node.skin.get_bind_name(bind)) if node.skin.get_bind_name(bind)!=&"" else node.skin.get_bind_bone(bind)
   palette.append(rig.global_transform*rig.get_bone_global_pose(bone)*node.skin.get_bind_pose(bind))
   torso.append(rig.get_bone_name(bone)=="pelvis" or rig.get_bone_name(bone).begins_with("spine_"))
  for surface in node.mesh.get_surface_count():
   var arrays:Array=node.mesh.surface_get_arrays(surface)
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
   var slots:int=weights.size()/vertices.size()
   for vertex in vertices.size():
    var point:=Vector3.ZERO;var torso_weight:=0.0
    for slot in slots:
     var offset:=vertex*slots+slot;var weight:=weights[offset]
     if weight>0:
      point+=(palette[bones[offset]]*vertices[vertex])*weight
      if torso[bones[offset]]:torso_weight+=weight
    var local:=actor.to_local(point)
    if torso_weight>.65 and absf(local.y-hip.y-.12)<.024:samples.append(local)
 var result:Array[Vector3]=[]
 for side in sides:
  var angle:=TAU*side/sides
  var radial:=Vector3(cos(angle),0,-sin(angle));var radius:=0.0
  for sample in samples:
   var offset:=sample-hip;offset.y=0
   if offset.length_squared()>.0001 and offset.normalized().dot(radial)>.97:radius=maxf(radius,offset.dot(radial))
  if radius<.05:radius=.17
  var at:=hip+Vector3.UP*.12+radial*(radius+.014)
  result.append(pelvis.affine_inverse()*rig.to_local(actor.to_global(at)))
 actor.set_meta("waist_fit_samples",samples.size())
 return result
