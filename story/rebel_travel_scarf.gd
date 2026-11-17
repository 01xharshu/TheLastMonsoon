extends RefCounted
## Wrap measured against the existing rebel MPFB export in its neutral pose.
## The rest-frame conversion makes the cloth follow the same head as the face.
static var shared_mesh: ArrayMesh
static var cotton: StandardMaterial3D

static func fit(actor: Node3D, rig: Skeleton3D) -> MeshInstance3D:
	if shared_mesh == null:
		shared_mesh = make_wrap()
		cotton = StandardMaterial3D.new()
		cotton.albedo_color = Color(.19,.22,.27)
		cotton.roughness = .94
		cotton.cull_mode = BaseMaterial3D.CULL_DISABLED
		cotton.vertex_color_use_as_albedo = true
	var joint := rig.find_bone("head")
	var anchor := BoneAttachment3D.new()
	anchor.bone_name = "head"
	rig.add_child(anchor)
	var scarf := MeshInstance3D.new()
	scarf.name = "TravelFaceScarf"
	scarf.mesh = shared_mesh
	scarf.material_override = cotton
	scarf.transform = rig.get_bone_global_rest(joint).affine_inverse() * rig.global_transform.affine_inverse() * actor.global_transform
	scarf.visibility_range_end = 100.0
	scarf.hide()
	anchor.add_child(scarf)
	return scarf

static func make_wrap() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	const SEGMENTS := 32
	const ROWS := 8
	for row in ROWS:
		for segment in SEGMENTS:
			for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(1,0)]:
				var u := float(segment+corner.x)/SEGMENTS
				var v := float(row+corner.y)/ROWS
				var angle := u*TAU
				var front := cos(angle)
				var across := sin(angle)
				var radius := lerpf(.083,.091,v)
				var bridge := pow(maxf(0.0,front),3.0)
				var lower_edge := 1.419 - .026*bridge + .007*sin(angle)
				var upper_edge := 1.485 + .031*bridge + .004*sin(angle)
				var y := lerpf(lower_edge,upper_edge,v) + .002*sin(angle*3.0+v*7.0)
				var fold := .0025*sin(v*TAU*2.0+angle*1.7)*sin(v*PI)
				var depth := lerpf(.088,.127,smoothstep(0.0,.78,v)) if front >= 0 else .106
				var z := .057 + signf(front)*pow(absf(front),.62)*(depth+fold)
				var selvage := .78 if v>.87 or v<.13 else 1.0
				var thread := selvage * (.93 + .07*sin(angle*9.0+v*12.0))
				surface.set_color(Color(thread,thread,thread,1.0))
				surface.set_uv(Vector2(u,v))
				surface.add_vertex(Vector3(signf(across)*pow(absf(across),.72)*(radius+fold),y,z))
	surface.generate_normals()
	surface.index()
	return surface.commit()
