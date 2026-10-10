extends RefCounted
## Small plot batches; no per-plant nodes, colliders, textures or update loops.
static var leaf_mesh: ArrayMesh
static var foliage: ShaderMaterial
static var soil: StandardMaterial3D

static func plant_mesh() -> ArrayMesh:
	if leaf_mesh!=null:return leaf_mesh
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for leaf in 7:
		var angle:=leaf*TAU/7.0
		var direction:=Vector3(sin(angle),0,cos(angle))
		var side:=Vector3(cos(angle),0,-sin(angle))*.044
		var points:Array[Vector3]=[]
		var uv:Array[Vector2]=[]
		for segment in 6:
			var t:=float(segment)/5
			var center:=direction*(.25*t*t)+Vector3.UP*(.46*t-.18*t*t)
			var width:float=sin(t*PI)*(.8+.2*t)
			points.append(center-side*width);points.append(center+side*width)
			uv.append(Vector2(0,t));uv.append(Vector2(1,t))
		for segment in 5:
			var start:=segment*2
			for index in [start,start+1,start+2,start+2,start+1,start+3]:
				st.set_uv(uv[index]);st.add_vertex(points[index])
	st.generate_normals();leaf_mesh=st.commit();return leaf_mesh

static func build(parent:Node3D,layout:RefCounted,size:Vector2,seed_value:int,young:=false) -> void:
	if foliage==null:
		foliage=ShaderMaterial.new();foliage.shader=preload("res://world/suryagarh/settlements/farm_foliage.gdshader")
	if soil==null:
		soil=StandardMaterial3D.new();soil.albedo_texture=preload("res://assets/nature/materials/brown_mud_dry_diff_1k.jpg")
		soil.uv1_scale=Vector3(2,2,1);soil.albedo_color=Color(.67,.59,.46);soil.roughness=1
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var rows:=3 if size.y<5 else 6
	var columns:=maxi(1,int((size.x-1)/.32))
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true
	mm.mesh=plant_mesh();mm.instance_count=rows*columns
	for row in rows:
		for column in columns:
			var index:=row*columns+column
			var x:float=-size.x*.5+.5+column*.32+rng.randf_range(-.045,.045)
			var z:float=-size.y*.5+.65+row*(size.y-1.3)/maxi(1,rows-1)+rng.randf_range(-.06,.06)
			var point:=parent.to_global(Vector3(x,0,z));point.y=layout.height(point.x,point.z)+.065
			var scale_value:=rng.randf_range(.65,1.2)*(.5 if young else 1.0)
			# Occasional gaps and patch-scale vigor break repeated carpet patterns.
			if rng.randf()<.045:scale_value=0
			mm.set_instance_transform(index,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_value),parent.to_local(point)))
			mm.set_instance_color(index,Color(.22,.32,.075).lerp(Color(.40,.43,.15),rng.randf()*.65).srgb_to_linear())
	var batch:=MultiMeshInstance3D.new();batch.name="FarmPlants";batch.multimesh=mm;batch.material_override=foliage
	batch.visibility_range_end=100;batch.visibility_range_end_margin=15
	batch.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(batch)
	# A subdivided soil surface follows the same survey as plant roots.
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps_x:=int(size.x*2);var steps_z:=ceili(size.y*2)
	for row in steps_z:
		for column in steps_x:
			for corner:Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var p:=Vector2(-size.x*.5+(column+corner.x)*size.x/steps_x,-size.y*.5+(row+corner.y)*size.y/steps_z)
				# Worked ridges fall into the ground at their margins, avoiding slab edges.
				var edge:=clampf(minf(size.x*.5-absf(p.x),size.y*.5-absf(p.y))/.35,0,1)
				var ridge:float=.012+.025*(.5+.5*cos((p.y+size.y*.5-.65)*TAU/((size.y-1.3)/maxi(1,rows-1))))
				var point:=parent.to_global(Vector3(p.x,0,p.y));point.y=layout.height(point.x,point.z)+.012+ridge*edge
				st.set_uv(p/2);st.add_vertex(parent.to_local(point))
	st.generate_normals()
	var bed:=MeshInstance3D.new();bed.name="FarmFurrows";bed.mesh=st.commit();bed.material_override=soil
	bed.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;bed.visibility_range_end=160;bed.visibility_range_end_margin=20;parent.add_child(bed)
	parent.set_meta("farm_plant_count",mm.instance_count)
