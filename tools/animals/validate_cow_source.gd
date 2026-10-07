extends SceneTree
func _initialize()->void:
 var cow:Node3D=load("res://assets/animals/cow/household_cow.glb").instantiate();root.add_child(cow)
 var errors:Array[String]=[]
 var meshes:=0
 for mesh:MeshInstance3D in cow.find_children("*","MeshInstance3D",true,false):
  for surface in mesh.mesh.get_surface_count():
   var arrays:=mesh.mesh.surface_get_arrays(surface)
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   if arrays[Mesh.ARRAY_TEX_UV]==null or arrays[Mesh.ARRAY_TEX_UV].size()!=vertices.size():errors.append(str(mesh.name)+": missing UVs")
   meshes+=1
 var body:MeshInstance3D=cow.find_child("Continuous cow skin",true,false)
 var breath:=-1
 for index in body.mesh.get_blend_shape_count():
  if body.mesh.get_blend_shape_name(index)=="Breath":breath=index
 if breath<0:errors.append("breathing morph missing")
 else:
  var shapes:Array=body.mesh.surface_get_blend_shape_arrays(0)
  var offsets:PackedVector3Array=shapes[breath][Mesh.ARRAY_VERTEX]
  var peak:=0.0
  var base:PackedVector3Array=body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  for index in offsets.size():
   var displacement:Vector3=offsets[index]-base[index] if body.mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_NORMALIZED else offsets[index]
   peak=maxf(peak,displacement.length())
  if peak<.001 or peak>.007:errors.append("breathing morph displacement outside intended subtle range")
  print("BREATH GEOMETRY MAX MM ",peak*1000)
 var rig:Skeleton3D=cow.find_children("*","Skeleton3D",true,false)[0]
 if rig.get_bone_count()!=19:errors.append("rig contract changed")
 print("COW SOURCE ","PASS" if errors.is_empty() else "FAIL"," surfaces ",meshes," errors ",errors)
 cow.queue_free();quit(0 if errors.is_empty() else 1)
