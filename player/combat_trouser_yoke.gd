extends RefCounted
## A same-body cotton crotch panel joins the two loose trouser legs.
static func apply(model: Node3D, skeleton: Skeleton3D) -> int:
	var garment: Node3D=preload("res://characters/arjun/combat_trouser_yoke.glb").instantiate()
	model.add_child(garment)
	var source_rig: Skeleton3D=garment.find_children("*","Skeleton3D",true,false)[0]
	var cotton: Material
	for trousers in model.find_children("*DrapedTrousers*", "MeshInstance3D", true, false):
		if trousers.mesh != null and trousers.mesh.get_surface_count() > 0:
			cotton = trousers.get_active_material(0)
			break
	var added:=0
	for mesh in garment.find_children("*","MeshInstance3D",true,false):
		if mesh.skin==null:continue
		var placement: Transform3D=model.global_transform.affine_inverse()*mesh.global_transform
		mesh.reparent(model,false)
		mesh.transform=placement
		var fitted_skin: Skin=mesh.skin.duplicate()
		for bind in fitted_skin.get_bind_count():
			var bone_name: StringName=fitted_skin.get_bind_name(bind)
			if bone_name==&"":bone_name=source_rig.get_bone_name(fitted_skin.get_bind_bone(bind))
			fitted_skin.set_bind_name(bind,bone_name)
			fitted_skin.set_bind_bone(bind,skeleton.find_bone(bone_name))
		# Share the live cotton material so imported linear colour cannot form a bright patch.
		if "Trouser fitted" in str(mesh.name) and cotton != null:
			mesh.material_override = cotton
		mesh.skin=fitted_skin
		mesh.skeleton=mesh.get_path_to(skeleton)
		mesh.set_meta("fitting_source","complete live MPFB body; upper trouser yoke")
		added+=1
	garment.free()
	return added
