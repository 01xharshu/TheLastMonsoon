extends RefCounted
## Temporary expression deltas on duplicated complete MPFB meshes; no topology removal.
var entries: Array[Dictionary]=[]
func configure(model: Node3D) -> void:
	var head_top:=0.0
	for node in model.find_children("*","MeshInstance3D",true,false):
		if "body" in node.name.to_lower():head_top=maxf(head_top,node.get_aabb().end.y)
	if head_top<=0:return
	var eye_height: float=head_top-.15
	for node in model.find_children("*","MeshInstance3D",true,false):
		if "eyes" in node.name.to_lower():eye_height=node.get_aabb().get_center().y
	for node in model.find_children("*","MeshInstance3D",true,false):
		var label: String=node.name.to_lower()
		if not ("body" in label or "eyebrow" in label or "moustache" in label):continue
		var source:=node.mesh as ArrayMesh
		if source==null or source.get_blend_shape_count()>0:continue
		var mesh:=ArrayMesh.new();mesh.blend_shape_mode=Mesh.BLEND_SHAPE_MODE_RELATIVE
		mesh.add_blend_shape("dialogue_concern");mesh.add_blend_shape("dialogue_disdain");mesh.add_blend_shape("dialogue_anger")
		for surface in source.get_surface_count():
			var base: Array=source.surface_get_arrays(surface)
			var points: PackedVector3Array=base[Mesh.ARRAY_VERTEX]
			var shapes: Array[Array]=[]
			for emotion in ["concern","disdain","anger"]:
				var shape: Array=[];shape.resize(Mesh.ARRAY_MAX)
				var offsets:=PackedVector3Array();offsets.resize(points.size())
				for i in points.size():
					var p:=points[i]
					if p.z<.10:continue
					var brow: float=exp(-pow((p.y-(eye_height+.018))/.018,2))*exp(-pow(p.x/.065,4))
					var mouth: float=exp(-pow((p.y-(eye_height-.105))/.013,2))*exp(-pow(p.x/.04,4))
					if emotion=="concern":offsets[i].y=brow*.003*(1.0-smoothstep(.01,.05,absf(p.x)))-mouth*.0015*smoothstep(.01,.03,absf(p.x))
					elif emotion=="disdain":offsets[i].y=-brow*.0015+mouth*.002*smoothstep(0,.03,p.x)
					else:offsets[i].y=-brow*.003*(1.0-smoothstep(.015,.055,absf(p.x)))
				shape[Mesh.ARRAY_VERTEX]=offsets
				if base[Mesh.ARRAY_NORMAL]!=null:
					var normals:=PackedVector3Array();normals.resize(points.size());shape[Mesh.ARRAY_NORMAL]=normals
				if base[Mesh.ARRAY_TANGENT]!=null:
					var tangents:=PackedFloat32Array();tangents.resize(points.size()*4);shape[Mesh.ARRAY_TANGENT]=tangents
				shapes.append(shape)
			mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface),base,shapes,{},source.surface_get_format(surface)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			mesh.surface_set_material(surface,source.surface_get_material(surface))
		node.mesh=mesh;entries.append({"node":node,"source":source})
func apply(concern: float, disdain: float, anger: float=0.0) -> void:
	for entry in entries:
		if is_instance_valid(entry.node):
			entry.node.set_blend_shape_value(0,clampf(concern,0,1))
			entry.node.set_blend_shape_value(1,clampf(disdain,0,1))
			entry.node.set_blend_shape_value(2,clampf(anger,0,1))
func restore() -> void:
	for entry in entries:
		if is_instance_valid(entry.node):entry.node.mesh=entry.source
	entries.clear()
