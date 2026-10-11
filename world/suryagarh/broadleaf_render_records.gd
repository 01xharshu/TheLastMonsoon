extends RefCounted
## Remove only exactly collapsed rendering records, after tree support setup.
## Preserve bounds and source slots so culling/LOD and world identity do not shift.
static func compact(source: MultiMesh) -> MultiMesh:
	if source.transform_format!=MultiMesh.TRANSFORM_3D: return source
	var stride := 12+(4 if source.use_colors else 0)+(4 if source.use_custom_data else 0)
	var buffer := source.buffer
	if buffer.size()!=source.instance_count*stride: return source
	var slots := PackedInt32Array()
	var source_slots: PackedInt32Array=source.get_meta("render_source_slots",PackedInt32Array())
	var packed := PackedFloat32Array()
	var visible := 0
	for index in source.instance_count:
		var offset := index*stride
		var collapsed := true
		for component in [0,1,2,4,5,6,8,9,10]:
			if buffer[offset+component]!=0.0: collapsed=false;break
		if collapsed: continue
		slots.append(source_slots[index] if source_slots.size()==source.instance_count else index)
		for component in stride: packed.append(buffer[offset+component])
		if source.visible_instance_count<0 or index<source.visible_instance_count: visible+=1
	if slots.size()==source.instance_count: return source
	var result := MultiMesh.new()
	result.transform_format=source.transform_format
	result.use_colors=source.use_colors
	result.use_custom_data=source.use_custom_data
	result.mesh=source.mesh
	result.instance_count=slots.size()
	result.visible_instance_count=-1 if source.visible_instance_count<0 else visible
	result.physics_interpolation_quality=source.physics_interpolation_quality
	# Retain the original box exactly: tighter bounds could change existing LOD.
	result.custom_aabb=source.get_aabb()
	result.buffer=packed
	for key in source.get_meta_list(): result.set_meta(key,source.get_meta(key))
	result.set_meta("render_source_slots",slots)
	return result

static func configure_landscape(landscape: Node3D) -> int:
	var removed := 0
	var nature := landscape.get_node_or_null("NatureTiles")
	if nature==null: return 0
	for batch in nature.find_children("BroadleafTrees*","MultiMeshInstance3D",true,false):
		await preload("res://systems/world_startup.gd").checkpoint(landscape,"Preparing tree rendering…")
		var source: MultiMesh=batch.multimesh
		var reduced := compact(source)
		removed+=source.instance_count-reduced.instance_count
		batch.multimesh=reduced
	landscape.set_meta("broadleaf_removed_render_records",removed)
	return removed
