extends RefCounted
## Rebinds only donor clothing to Arjun; never swaps or masks the human body.
var additions: Array[Node3D]=[]
var originals: Array[GeometryInstance3D]=[]
var original_visible: Array[bool]=[]
var worn=false
func wear(visual: Node3D,guard: Node3D) -> bool:
 if worn:return true
 var rig: Skeleton3D=visual.skeleton
 var donor: Skeleton3D=guard._skeleton
 for node in guard.find_children("*","MeshInstance3D",true,false):
  if node.skin==null or node.mesh==null:continue
  var label=str(node.name).to_lower()
  if not ("casualsuit" in label or "shoes04" in label):continue
  var skin=Skin.new()
  for i in node.skin.get_bind_count():
   var bone=node.skin.get_bind_bone(i)
   var donor_name=str(node.skin.get_bind_name(i))
   if donor_name.is_empty() and bone>=0:donor_name=donor.get_bone_name(bone)
   var index=rig.find_bone(donor_name)
   if index<0:return false
   skin.add_bind(index,rig.get_bone_global_rest(index).affine_inverse())
  var mesh=ArrayMesh.new()
  for surface in node.mesh.get_surface_count():
   var arrays: Array=node.mesh.surface_get_arrays(surface)
   var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
   var indices: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
   var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
   var stride=int(indices.size()/vertices.size())
   for vertex in vertices.size():
    var at=Vector3.ZERO;var normal=Vector3.ZERO
    for influence in stride:
     var bind=indices[vertex*stride+influence];var weight=weights[vertex*stride+influence]
     if weight<=0:continue
     var correction=rig.get_bone_global_rest(skin.get_bind_bone(bind))*node.skin.get_bind_pose(bind)
     at+=(correction*vertices[vertex])*weight
     normal+=(correction.basis.inverse().transposed()*normals[vertex])*weight
    vertices[vertex]=at+normal.normalized()*.018;normals[vertex]=normal.normalized()
   arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
   mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   mesh.surface_set_material(surface,node.get_active_material(surface))
  var clothing=MeshInstance3D.new();clothing.name="CapturedUniform";clothing.mesh=mesh;clothing.skin=skin;rig.add_child(clothing);clothing.skeleton=clothing.get_path_to(rig);additions.append(clothing)
 if additions.is_empty():return false
 for node in visual.find_children("*","MeshInstance3D",true,false):
  if node in additions:continue
  if node.skin==null and not ("boot" in str(node.name).to_lower() or "sash" in str(node.name).to_lower() or "kurta" in str(node.name).to_lower()):continue
  var label=str(node.name).to_lower()
  if "base." in label or "short02" in label or "high-poly" in label or "eyebrow" in label:continue
  originals.append(node);original_visible.append(node.visible);node.hide()
 # Keep the incapacitated guard's complete body and opaque short04 foundation.
 for node in guard.find_children("*","MeshInstance3D",true,false):
  var label=str(node.name).to_lower()
  if "casualsuit" in label or "crossbelt" in label or "cap" in label or "shoes04" in label:node.hide()
 worn=true;return true
func remove() -> void:
 for i in originals.size():
  if is_instance_valid(originals[i]):originals[i].visible=original_visible[i]
 for node in additions:
  if is_instance_valid(node):node.queue_free()
 additions.clear();originals.clear();original_visible.clear();worn=false
