extends RefCounted
## Instance-only fabric treatment and a skinned work apron; shared farmer source stays intact.
func dress(actor: Node3D) -> void:
	var cook: bool=actor.household_job=="Cook"
	var upper: MeshInstance3D
	var lower: MeshInstance3D
	for node: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		var label := node.name.to_lower()
		var garment := "dhoti" in label or "kurta" in label or "wrap" in label or "casualsuit" in label or "upper_cutout" in label
		if not garment: continue
		if "casualsuit" in label or "upper_cutout" in label: upper=node
		if "kurta" in label: lower=node
		var color := Color(.56,.51,.40) if cook else Color(.33,.39,.36)
		if "dhoti" in label: color=Color(.47,.44,.35) if cook else Color(.58,.54,.44)
		if "wrap" in label: color=Color(.62,.57,.45) if cook else Color(.38,.30,.20)
		if "border" in label or "fold" in label: color*=.68
		for surface in node.mesh.get_surface_count():
			var fabric := ShaderMaterial.new()
			fabric.shader=preload("res://characters/npcs/households/fort_staff_fabric.gdshader")
			fabric.set_shader_parameter("cloth_color",color)
			fabric.set_shader_parameter("work_stains",.16 if cook else .05)
			node.set_surface_override_material(surface,fabric)
		actor.set_meta("staff_cloth_surfaces",int(actor.get_meta("staff_cloth_surfaces",0))+node.mesh.get_surface_count())
	if upper != null and lower != null: tailored_hem(upper,lower)
	if cook and upper != null: apron(upper)

func apron(source: MeshInstance3D) -> void:
	var original := source.mesh.surface_get_arrays(0)
	var points: PackedVector3Array=original[Mesh.ARRAY_VERTEX]
	var joints: PackedInt32Array=original[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array=original[Mesh.ARRAY_WEIGHTS]
	if joints.is_empty(): return
	var rig: Skeleton3D=source.get_node(source.skeleton)
	var torso_binds: Array[int]=[]
	for name in ["pelvis","spine_01","spine_02"]:
		var bone := rig.find_bone(name)
		var found := -1
		for bind in source.skin.get_bind_count():
			if source.skin.get_bind_bone(bind)==bone or str(source.skin.get_bind_name(bind))==name: found=bind; break
		if found<0: return
		torso_binds.append(found)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var bones := PackedInt32Array()
	var skin_weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	var rows := 20
	var columns := 18
	for row in rows+1:
		var v := float(row)/rows
		var y := lerpf(1.27,.61,v)
		var width := lerpf(.135,.255,smoothstep(.35,.7,v))
		for column in columns+1:
			var u := float(column)/columns
			var x := (u*2-1)*width
			var z := lerpf(.254,.233,v)+sin(u*TAU*5)*.012*smoothstep(.3,.75,v)
			var position := Vector3(x,y,z)
			vertices.append(position)
			normals.append(Vector3(0,0,1))
			uv.append(Vector2(u,v))
			var lower_blend := smoothstep(.82,1.07,y)
			var upper_blend := smoothstep(1.07,1.32,y)
			bones.append_array(PackedInt32Array([torso_binds[0],torso_binds[1],torso_binds[2],0]))
			skin_weights.append_array(PackedFloat32Array([1.0-lower_blend,lower_blend*(1.0-upper_blend),lower_blend*upper_blend,0]))
	for row in rows:
		for column in columns:
			var a := row*(columns+1)+column
			indices.append_array(PackedInt32Array([a,a+1,a+columns+1,a+1,a+columns+2,a+columns+1]))
	# Narrow neck straps continue the bib over the shoulders, retaining torso weights.
	for side in [-1.0,1.0]:
		var offset := vertices.size()
		for row in 9:
			var v := float(row)/8.0
			var y := lerpf(1.25,1.41,v)
			for column in 2:
				vertices.append(Vector3(side*lerpf(.105,.16,v)+(float(column)-.5)*.025,y,lerpf(.255,.17,v)))
				normals.append(Vector3(0,0,1));uv.append(Vector2(float(column),v))
				bones.append_array(PackedInt32Array([torso_binds[2],0,0,0]))
				skin_weights.append_array(PackedFloat32Array([1,0,0,0]))
		for row in 8:
			var a := offset+row*2
			indices.append_array(PackedInt32Array([a,a+1,a+2,a+1,a+3,a+2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_BONES]=bones
	arrays[Mesh.ARRAY_WEIGHTS]=skin_weights
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var garment := MeshInstance3D.new()
	garment.name="CookSkinnedWorkApron"
	garment.mesh=mesh
	garment.skin=source.skin
	garment.skeleton=source.skeleton
	garment.transform=source.transform
	var material := ShaderMaterial.new()
	material.shader=preload("res://characters/npcs/households/fort_staff_fabric.gdshader")
	material.set_shader_parameter("cloth_color",Color(.39,.32,.23))
	material.set_shader_parameter("work_stains",.24)
	material.set_shader_parameter("apron",true)
	garment.material_override=material
	source.get_parent().add_child(garment)

func tailored_hem(upper: MeshInstance3D,lower: MeshInstance3D) -> void:
	# Trim the old pointed shirt tails; the continuous folded skirt overlaps this edge.
	var upper_mesh := ArrayMesh.new()
	for surface in upper.mesh.get_surface_count():
		var arrays := upper.mesh.surface_get_arrays(surface)
		var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var old_indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var indices := PackedInt32Array()
		for triangle in old_indices.size()/3:
			var a:=old_indices[triangle*3];var b:=old_indices[triangle*3+1];var c:=old_indices[triangle*3+2]
			if minf(positions[a].y,minf(positions[b].y,positions[c].y))>=.945:
				indices.append_array(PackedInt32Array([a,b,c]))
		arrays[Mesh.ARRAY_INDEX]=indices
		upper_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	upper.mesh=upper_mesh
	var rig: Skeleton3D=lower.get_node(lower.skeleton)
	var pelvis := rig.find_bone("pelvis")
	var bind := 0
	for index in lower.skin.get_bind_count():
		if lower.skin.get_bind_bone(index)==pelvis or str(lower.skin.get_bind_name(index))=="pelvis":bind=index;break
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var uv:=PackedVector2Array()
	var bones:=PackedInt32Array();var weights:=PackedFloat32Array();var indices:=PackedInt32Array()
	for row in 9:
		var v:=float(row)/8.0
		for column in 65:
			var u:=float(column)/64.0;var angle:=u*TAU
			var fold:=sin(angle*10.0+v*.5)*.006
			var radius_x:=lerpf(.225,.24,v)+fold
			var radius_z:=lerpf(.245,.22,v)+fold
			vertices.append(Vector3(cos(angle)*radius_x,lerpf(1.01,.66,v),sin(angle)*radius_z))
			normals.append(Vector3(cos(angle),0,sin(angle)).normalized());uv.append(Vector2(u,v))
			bones.append_array(PackedInt32Array([bind,0,0,0]));weights.append_array(PackedFloat32Array([1,0,0,0]))
	for row in 8:
		for column in 64:
			var a:=row*65+column
			indices.append_array(PackedInt32Array([a,a+65,a+1,a+1,a+65,a+66]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	lower.mesh=mesh
