extends RefCounted
## Keep the gathered waist anchored while the legs bend independently.
static func apply(model: Node3D) -> int:
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
    var waist := smoothstep(.82, .98, height)
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
