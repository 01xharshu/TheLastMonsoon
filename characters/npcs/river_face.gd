extends RefCounted
## Preserve original facial identities; append lightweight acting shapes once.
static var cache := {}
var mesh_node: MeshInstance3D
var indices: Array[int] = []

func configure(actor: Node3D) -> void:
	for node: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if "makehuman_body" not in str(node.name).to_lower():continue
		var source := node.mesh as ArrayMesh
		if source==null:continue
		var id:=source.get_instance_id()
		if not cache.has(id):
			# The existing expression builder uses the same complete vertex arrays.
			# A temporary node supplies dimensions only; no human geometry is made.
			var plain:=ArrayMesh.new()
			for surface in source.get_surface_count():
				plain.add_surface_from_arrays(source.surface_get_primitive_type(surface),source.surface_get_arrays(surface),[],{},source.surface_get_format(surface)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
				plain.surface_set_material(surface,source.surface_get_material(surface))
			var temp:=Node3D.new();var body:=MeshInstance3D.new();body.name="MakeHuman_body";body.mesh=plain;temp.add_child(body)
			var expr:=preload("res://story/dialogue_expression.gd").new();expr.configure(temp)
			var expressions:=body.mesh as ArrayMesh
			var result:=ArrayMesh.new();result.blend_shape_mode=Mesh.BLEND_SHAPE_MODE_NORMALIZED
			for shape in source.get_blend_shape_count():result.add_blend_shape(source.get_blend_shape_name(shape))
			for shape in expressions.get_blend_shape_count():result.add_blend_shape(expressions.get_blend_shape_name(shape))
			for surface in source.get_surface_count():
				var shapes: Array[Array]=source.surface_get_blend_shape_arrays(surface)
				shapes.append_array(expressions.surface_get_blend_shape_arrays(surface))
				result.add_surface_from_arrays(source.surface_get_primitive_type(surface),source.surface_get_arrays(surface),shapes,{},source.surface_get_format(surface)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
				result.surface_set_material(surface,source.surface_get_material(surface))
			temp.free();cache[id]=result
		node.mesh=cache[id];mesh_node=node
		for label in ["dialogue_speech","dialogue_concern","dialogue_blink"]:indices.append(node.find_blend_shape_by_name(label))
		return

func update(time: float, speaking: bool, fear := 0.0) -> void:
	if not is_instance_valid(mesh_node):return
	var expr=preload("res://story/dialogue_expression.gd")
	var values: Array[float]=[expr.speech_weight(fposmod(time,8.0),8.0) if speaking else 0.0,fear,expr.blink_weight(time)]
	for index in indices.size():
		if indices[index]>=0:mesh_node.set_blend_shape_value(indices[index],values[index])
