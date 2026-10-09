extends RefCounted
## Complete MPFB body, foundation and fitted garments for every player load.
func apply(visual: Node3D) -> void:
	var model: Node3D = visual.model
	if model.has_meta("opening_clothing_fitted"): return
	var donor: Node3D = load("res://characters/arjun/arjun_opening_fit.glb").instantiate()
	visual.add_child(donor)
	donor.transform = model.transform
	donor.hide()
	var donor_rig: Skeleton3D = donor.find_children("*","Skeleton3D",true,false)[0]
	var body: MeshInstance3D = model.find_child("Arjun_MakeHuman_Body",true,false)
	var live_skin: Skin = body.skin
	var count := 0
	for source_node in donor.find_children("*","MeshInstance3D",true,false):
		var source := source_node as MeshInstance3D
		if source.skin == null: continue
		var target := model.find_child(str(source.name),true,false) as MeshInstance3D
		if target == null:
			if source.name != "Arjun_Foundation_FittedShorts": continue
			target = MeshInstance3D.new()
			target.name = source.name
			body.get_parent().add_child(target)
			target.transform = body.transform
			target.skeleton = target.get_path_to(visual.skeleton)
			target.skin = live_skin
		var destination_binds := {}
		for bind in target.skin.get_bind_count(): destination_binds[_bind_name(target.skin,bind,visual.skeleton)] = bind
		assert(destination_binds.size() == target.skin.get_bind_count(),"Opening skin bind names must be unique")
		var remap: Array[int] = []
		for bind in source.skin.get_bind_count():
			var bone := _bind_name(source.skin,bind,donor_rig)
			if not destination_binds.has(bone):
				push_error("Opening clothing bind missing: "+bone)
				donor.free()
				return
			remap.append(destination_binds[bone])
		var frame: Transform3D = target.global_transform.affine_inverse()*source.global_transform
		var normal_frame := frame.basis.inverse().transposed()
		var fitted := ArrayMesh.new()
		for surface in source.mesh.get_surface_count():
			var arrays: Array = source.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			for i in points.size():
				points[i] = frame*points[i]
				normals[i] = (normal_frame*normals[i]).normalized()
			for i in bones.size(): bones[i] = remap[bones[i]]
			arrays[Mesh.ARRAY_VERTEX] = points
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_TANGENT] = null
			if source.name == "Arjun_MakeHuman_Body":
				# This source has anatomical UVs, not the runtime packed atlas.
				arrays[Mesh.ARRAY_TEX_UV2] = arrays[Mesh.ARRAY_TEX_UV].duplicate()
			fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},source.mesh.surface_get_format(surface)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			var material: Material = source.mesh.surface_get_material(surface)
			if source.name == "Arjun_MakeHuman_Body" and material is BaseMaterial3D:
				var skin := target.get_surface_override_material(surface).duplicate() as ShaderMaterial
				skin.set_shader_parameter("base_atlas",material.albedo_texture)
				skin.set_shader_parameter("atlas_tint",Vector3(.44,.35,.30))
				target.set_surface_override_material(surface,skin)
			if target.mesh != null:
				material = target.mesh.surface_get_material(mini(surface,target.mesh.get_surface_count()-1))
			fitted.surface_set_material(surface,material)
		target.mesh = fitted
		count += 1
	model.set_meta("opening_clothing_fitted",count)
	donor.free()

func _bind_name(skin: Skin, bind: int, rig: Skeleton3D) -> String:
	var name := str(skin.get_bind_name(bind))
	if name == "": name = rig.get_bone_name(skin.get_bind_bone(bind))
	return name
