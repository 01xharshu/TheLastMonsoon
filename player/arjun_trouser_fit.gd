extends RefCounted
## Keep the gathered waist anchored while the legs bend independently.
static func apply(model: Node3D) -> int:
 _apply_source_folds(model)
 var adjusted := 0
 for candidate in model.find_children("*DrapedTrousers*", "MeshInstance3D", true, false):
  var node := candidate as MeshInstance3D
  if node.skin == null: continue
  var side := "r" if str(node.name).ends_with("_-1") else "l"
  var binds := {}
  for index in node.skin.get_bind_count(): binds[str(node.skin.get_bind_name(index))] = index
  if not binds.has("pelvis") or not binds.has("thigh_"+side) or not binds.has("calf_"+side): continue
  var fitted := ArrayMesh.new()
  for surface in node.mesh.get_surface_count():
   var arrays := node.mesh.surface_get_arrays(surface)
   var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
   var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
   var influences: int = weights.size()/vertices.size()
   for vertex in vertices.size():
    var height := vertices[vertex].y
    # Match the overlying kurta's hip transition. The upper trouser
    # opening must remain on the pelvis while the lower fabric follows the thigh.
    var waist := smoothstep(.86, .95, height)
    var upper_leg := smoothstep(.43, .59, height)
    var offset := vertex*influences
    for slot in influences:
     bones[offset+slot] = 0
     weights[offset+slot] = 0.0
    bones[offset] = binds["pelvis"]
    bones[offset+1] = binds["thigh_"+side]
    bones[offset+2] = binds["calf_"+side]
    weights[offset] = waist
    weights[offset+1] = (1.0-waist)*upper_leg
    weights[offset+2] = (1.0-waist)*(1.0-upper_leg)
   arrays[Mesh.ARRAY_BONES] = bones
   arrays[Mesh.ARRAY_WEIGHTS] = weights
   fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, node.mesh.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
   fitted.surface_set_material(surface,node.mesh.surface_get_material(surface))
  node.mesh = fitted
  adjusted += 1
 return adjusted

static func _apply_source_folds(model: Node3D) -> void:
 var source: Node3D = preload("res://characters/arjun/arjun_riding_cloth.glb").instantiate()
 model.get_parent().add_child(source)
 source.transform = model.transform
 source.hide()
 for node in model.find_children("*","MeshInstance3D",true,false):
  if not ("DrapedTrousers" in str(node.name) or node.name == "Arjun_Kurta_SplitHem"): continue
  var replacement: MeshInstance3D = source.find_child(str(node.name),true,false)
  if replacement == null: continue
  var frame: Transform3D = node.global_transform.affine_inverse()*replacement.global_transform
  var normal_frame := frame.basis.inverse().transposed()
  var fitted := ArrayMesh.new()
  for surface in replacement.mesh.get_surface_count():
   var arrays := replacement.mesh.surface_get_arrays(surface)
   var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
   for index in vertices.size():
    vertices[index] = frame*vertices[index]
    normals[index] = (normal_frame*normals[index]).normalized()
   arrays[Mesh.ARRAY_VERTEX] = vertices
   arrays[Mesh.ARRAY_NORMAL] = normals
   arrays[Mesh.ARRAY_TANGENT] = null
   # The existing fitting pass assigns the live skin's named bind indices.
   arrays[Mesh.ARRAY_BONES] = PackedInt32Array()
   arrays[Mesh.ARRAY_BONES].resize(vertices.size()*4)
   arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array()
   arrays[Mesh.ARRAY_WEIGHTS].resize(vertices.size()*4)
   fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   var cotton := StandardMaterial3D.new()
   cotton.resource_name = "Unbleached draped cotton"
   cotton.albedo_color = Color(0.76,0.72,0.62)
   cotton.roughness = 0.93
   cotton.metallic_specular = 0.18
   fitted.surface_set_material(surface,node.mesh.surface_get_material(mini(surface,node.mesh.get_surface_count()-1)) if node.name == "Arjun_Kurta_SplitHem" else cotton)
  node.mesh = fitted
  node.set_meta("riding_cloth_source","arjun_riding_cloth.glb")
 source.free()
