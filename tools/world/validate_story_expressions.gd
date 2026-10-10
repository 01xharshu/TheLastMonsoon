extends SceneTree
## Expression geometry must preserve complete bodies, skinning and valid shading inputs.
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
 if not value:failures.append(message);push_error(message)
func arrays_close(first, second) -> bool:
 if first==null or second==null:return first==second
 if first.size()!=second.size():return false
 for index in first.size():
  if first is PackedVector3Array:
   if first[index].distance_to(second[index])>.001:return false
  elif absf(first[index]-second[index])>.001:return false
 return true
func run() -> void:
 for path in ["res://characters/arjun/arjun_opening_fit.glb","res://characters/npcs/british/official_man.glb","res://characters/npcs/households/merchant.glb"]:
  var model: Node3D=load(path).instantiate();root.add_child(model)
  var face=preload("res://story/dialogue_expression.gd").new();face.configure(model)
  check(not face.entries.is_empty(),"expression finds body on "+path)
  for entry in face.entries:
   var mesh: ArrayMesh=entry.node.mesh
   check(mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_NORMALIZED,"normalised expression preserves unit normal representation")
   for surface in mesh.get_surface_count():
    var base: Array=entry.source.surface_get_arrays(surface)
    var current: Array=mesh.surface_get_arrays(surface)
    check(current[Mesh.ARRAY_VERTEX]==base[Mesh.ARRAY_VERTEX],"base body positions preserved")
    check(current[Mesh.ARRAY_BONES]==base[Mesh.ARRAY_BONES] and current[Mesh.ARRAY_WEIGHTS]==base[Mesh.ARRAY_WEIGHTS],"complete body skin bindings preserved")
    for shape: Array in mesh.surface_get_blend_shape_arrays(surface):
     check(arrays_close(shape[Mesh.ARRAY_NORMAL],base[Mesh.ARRAY_NORMAL]),"shape normals match valid source normals")
     check(arrays_close(shape[Mesh.ARRAY_TANGENT],base[Mesh.ARRAY_TANGENT]),"shape tangents match source")
     var original: PackedVector3Array=base[Mesh.ARRAY_VERTEX]
     var changed: PackedVector3Array=shape[Mesh.ARRAY_VERTEX]
     for index in original.size():
      if original[index].y<1.3:check(changed[index]==original[index],"expression cannot deform limbs or torso")
  face.apply(.55,.2,.4,.65,.5)
  for entry in face.entries:
   var total:=0.0
   for index in 5:total+=entry.node.get_blend_shape_value(index)
   check(total<=1.0001,"combined facial weights remain bounded")
  face.restore()
  if "official_man" in path:
   var untouched: Dictionary={}
   for node in model.find_children("*","MeshInstance3D",true,false):
    if "body" in str(node.name).to_lower() or "foundation" in str(node.name).to_lower():untouched[node]=node.mesh
   var cloth=preload("res://story/collar_cloth.gd").new();cloth.configure(model)
   check(not cloth.entries.is_empty(),"collar tension finds fitted coat")
   cloth.apply(1)
   for node in untouched:check(node.mesh==untouched[node],"coat tension leaves body and foundation unchanged")
   for entry in cloth.entries:
    for surface in entry.source.get_surface_count():
     var original: Array=entry.source.surface_get_arrays(surface)
     var current: Array=entry.node.mesh.surface_get_arrays(surface)
     check(current[Mesh.ARRAY_VERTEX]==original[Mesh.ARRAY_VERTEX],"coat base geometry retained")
     check(current[Mesh.ARRAY_BONES]==original[Mesh.ARRAY_BONES] and current[Mesh.ARRAY_WEIGHTS]==original[Mesh.ARRAY_WEIGHTS],"coat skin bindings retained")
   cloth.restore()
  model.queue_free();await process_frame
 check(preload("res://story/dialogue_expression.gd").speech_weight(1.0,6.0)>0,"subtitle speech opens within the line")
 check(preload("res://story/dialogue_expression.gd").speech_weight(6.0,6.0)==0,"speech stops at line end")
 print("STORY EXPRESSIONS: "+("PASS" if failures.is_empty() else "FAIL "+str(failures)))
 quit(0 if failures.is_empty() else 1)
