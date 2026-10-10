extends RefCounted
## Local coat tension for the paired collar hold; complete body and foundations stay intact.
var entries: Array[Dictionary]=[]
func configure(actor: Node3D) -> void:
 for node in actor.find_children("*","MeshInstance3D",true,false):
  if not "fitted_cloth" in str(node.name).to_lower():continue
  var source: ArrayMesh=node.mesh as ArrayMesh
  if source==null or source.get_blend_shape_count()>0:continue
  var mesh:=ArrayMesh.new();mesh.blend_shape_mode=Mesh.BLEND_SHAPE_MODE_NORMALIZED
  mesh.add_blend_shape("collar_left_tension");mesh.add_blend_shape("collar_right_tension")
  for surface in source.get_surface_count():
   var base: Array=source.surface_get_arrays(surface)
   var points: PackedVector3Array=base[Mesh.ARRAY_VERTEX]
   var shapes: Array[Array]=[]
   for sign_side in [-1.0,1.0]:
    var shape: Array=[];shape.resize(Mesh.ARRAY_MAX)
    var shaped:=points.duplicate()
    for index in shaped.size():
     var p: Vector3=points[index]
     var patch: float=exp(-pow((p.x-sign_side*.09)/.048,2)-pow((p.y-1.34)/.085,2))*smoothstep(.06,.12,p.z)
     shaped[index]+=Vector3(-sign_side*.003,-.007,.012)*patch
    shape[Mesh.ARRAY_VERTEX]=shaped
    shape[Mesh.ARRAY_NORMAL]=base[Mesh.ARRAY_NORMAL]
    shape[Mesh.ARRAY_TANGENT]=base[Mesh.ARRAY_TANGENT]
    shapes.append(shape)
   mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface),base,shapes,{},source.surface_get_format(surface)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
   mesh.surface_set_material(surface,source.surface_get_material(surface))
  node.mesh=mesh;entries.append({"node":node,"source":source})
func apply(amount: float) -> void:
 for entry in entries:
  if is_instance_valid(entry.node):
   entry.node.set_blend_shape_value(0,clampf(amount,0,1)*.5)
   entry.node.set_blend_shape_value(1,clampf(amount,0,1)*.5)
func restore() -> void:
 for entry in entries:
  if is_instance_valid(entry.node):entry.node.mesh=entry.source
 entries.clear()
