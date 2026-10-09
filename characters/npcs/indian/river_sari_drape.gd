extends RefCounted
## Continuous fabric only. The original complete MPFB body stays in its rig.
const DIMENSIONS = preload("res://characters/npcs/indian/river_sari_dimensions.gd").DATA
const PLANE_COUNT := 24
var actor: Node3D
var rig: Skeleton3D
var pieces: Array[Dictionary] = []
var directions: PackedVector2Array = []
var planes: PackedVector2Array = []
var plane_rays: Array[Array] = []
var segments: int = int(DIMENSIONS.segments)
var rings: int = int(DIMENSIONS.rings)

func _init(owner: Node3D, skeleton: Skeleton3D) -> void:
	actor=owner;rig=skeleton
	for i in PLANE_COUNT:planes.append(Vector2(cos(TAU*i/PLANE_COUNT),sin(TAU*i/PLANE_COUNT)))
	for i in segments:
		var direction := Vector2(cos(TAU*i/segments),sin(TAU*i/segments))
		directions.append(direction)
		var row: Array=[]
		for j in PLANE_COUNT:
			var dot: float=planes[j].dot(direction)
			if dot>.0001:row.append(Vector2(j,1.0/dot))
		plane_rays.append(row)
	for node: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if str(node.name) not in ["Wrapped sari lower drape","Sari lower border"]:continue
		var mat: Material=node.mesh.surface_get_material(0)
		node.reparent(actor,false);node.transform=Transform3D.IDENTITY;node.skin=null;node.skeleton=NodePath()
		var border: bool=str(node.name)=="Sari lower border"
		var row_count := 2 if border else rings
		var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
		var vertices := PackedVector3Array();vertices.resize((row_count+1)*segments)
		var normals := PackedVector3Array();normals.resize(vertices.size());normals.fill(Vector3.UP)
		var uv := PackedVector2Array();uv.resize(vertices.size())
		var ids := PackedInt32Array()
		for row in row_count+1:
			for i in segments:uv[row*segments+i]=Vector2(float(i)/segments,float(row)/row_count)
		for row in row_count:
			for i in segments:
				var a := row*segments+i;var b := row*segments+(i+1)%segments
				ids.append_array(PackedInt32Array([a,a+segments,b,b,a+segments,b+segments]))
		arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=ids
		var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
		mesh.surface_set_material(0,mat);mesh.custom_aabb=AABB(Vector3(-1,-.1,-1),Vector3(2,2,2));node.mesh=mesh
		pieces.append({"node":node,"mesh":mesh,"border":border,"rows":row_count})

func _point(name: String) -> Vector3:
	return actor.to_local(rig.to_global(rig.get_bone_global_pose(rig.find_bone(name)).origin))

func _capsules() -> Array[Vector4]:
	var spheres: Array[Vector4]=[]
	for side in ["l","r"]:
		var hip := _point("thigh_"+side);var knee := _point("calf_"+side);var ankle := _point("foot_"+side)
		for pair in [[hip,knee,float(DIMENSIONS.thigh_radius)],[knee,ankle,float(DIMENSIONS.calf_radius)],[ankle,ankle+Vector3(0,-.025,-.16),float(DIMENSIONS.foot_radius)]]:
			for step in 9:
				var point: Vector3=Vector3(pair[0]).lerp(Vector3(pair[1]),float(step)/8.0)
				spheres.append(Vector4(point.x,point.y,point.z,float(pair[2])))
	return spheres

func update() -> void:
	if pieces.is_empty():return
	var bone: int=rig.find_bone(str(DIMENSIONS.waist_bone))
	var pose: Transform3D=rig.get_bone_global_pose(bone)
	var delta: Basis=pose.basis*rig.get_bone_global_rest(bone).basis.inverse()
	var waist := actor.to_local(rig.to_global(pose.origin+delta*Vector3.UP*float(DIMENSIONS.waist_offset)))
	var pelvis := _point("pelvis")
	var spheres := _capsules()
	var floor_y := 0.0
	var ground: Callable=actor.ground_height
	if ground.is_valid():floor_y=actor.to_local(Vector3(actor.global_position.x,float(ground.call(actor.global_position.x,actor.global_position.z)),actor.global_position.z)).y
	var terrain_span := 0.0
	if ground.is_valid():
		for offset in [Vector3(.5,0,0),Vector3(-.5,0,0),Vector3(0,0,.5),Vector3(0,0,-.5)]:
			var world := actor.to_global(offset)
			terrain_span=maxf(terrain_span,absf(actor.to_local(Vector3(world.x,float(ground.call(world.x,world.z)),world.z)).y-floor_y))
	var radii: Array[PackedFloat32Array]=[]
	for row in rings+1:
		var t := float(row)/rings
		var y := lerpf(waist.y,floor_y+.018,t)
		var band := .025+terrain_span*t
		var support := PackedFloat32Array();support.resize(PLANE_COUNT)
		var rx := lerpf(float(DIMENSIONS.waist_rx),float(DIMENSIONS.hem_radius),t)
		var rz := lerpf(float(DIMENSIONS.waist_ry),float(DIMENSIONS.hem_radius),t)
		var sections: Array[Vector3]=[]
		for sphere in spheres:
			var vertical: float=maxf(0.0,absf(sphere.y-y)-band)
			if vertical>=sphere.w:continue
			sections.append(Vector3(sphere.x-waist.x,sphere.z-waist.z,sqrt(maxf(0.0,sphere.w*sphere.w-vertical*vertical))+float(DIMENSIONS.clearance)))
		var hip_vertical: float=maxf(0.0,absf(pelvis.y-y)-band)
		var hip_scale: float=sqrt(maxf(0.0,1.0-pow(hip_vertical/float(DIMENSIONS.pelvis_height),2)))
		for j in PLANE_COUNT:
			var normal: Vector2=planes[j]
			var extent: float=sqrt(pow(rx*normal.x,2)+pow(rz*normal.y,2))
			for section in sections:
				extent=maxf(extent,normal.dot(Vector2(section.x,section.y))+section.z)
			if hip_vertical<float(DIMENSIONS.pelvis_height):
				var hip_extent: float=sqrt(pow(float(DIMENSIONS.pelvis_rx)*normal.x,2)+pow(float(DIMENSIONS.pelvis_ry)*normal.y,2))*hip_scale
				extent=maxf(extent,normal.dot(Vector2(pelvis.x-waist.x,pelvis.z-waist.z))+hip_extent+float(DIMENSIONS.clearance))
			support[j]=extent
		var radii_row := PackedFloat32Array();radii_row.resize(segments)
		for i in segments:
			var radius := 2.0
			for ray: Vector2 in plane_rays[i]:radius=minf(radius,support[int(ray.x)]*ray.y)
			radii_row[i]=radius+.003*(1.0+cos(TAU*i/segments*10.0))
		radii.append(radii_row)
	# Smooth dents outward so the fabric stays clear of its conservative bounds.
	for sweep in 2:
		for row in range(1,rings):
			for i in segments:radii[row][i]=maxf(radii[row][i],(radii[row-1][i]+radii[row+1][i])*.5)
	var hem_heights := PackedFloat32Array();hem_heights.resize(segments)
	for i in segments:
		var point := Vector3(waist.x+directions[i].x*radii[rings][i],0,waist.z+directions[i].y*radii[rings][i])
		hem_heights[i]=floor_y+.018
		if ground.is_valid():
			var world := actor.to_global(point)
			hem_heights[i]=actor.to_local(Vector3(world.x,float(ground.call(world.x,world.z)),world.z)).y+.018
	var drape := PackedVector3Array();drape.resize((rings+1)*segments)
	for row in rings+1:
		var t := float(row)/rings
		for i in segments:
			var direction: Vector2=directions[i]
			var point := Vector3(waist.x+direction.x*radii[row][i],0,waist.z+direction.y*radii[row][i])
			point.y=lerpf(waist.y,hem_heights[i],t);drape[row*segments+i]=point
	for piece in pieces:
		var points: PackedVector3Array=drape
		var row_count: int=piece.rows
		if piece.border:
			points=PackedVector3Array();points.resize((row_count+1)*segments)
			for row in row_count+1:
				for i in segments:
					var point: Vector3=drape[rings*segments+i];point.y+=.030*(1.0-float(row)/row_count)
					point+=Vector3(directions[i].x,0,directions[i].y)*.0015;points[row*segments+i]=point
		var normals := PackedVector3Array();normals.resize(points.size())
		for row in row_count+1:
			for i in segments:
				var across: Vector3=points[row*segments+(i+1)%segments]-points[row*segments+(i+segments-1)%segments]
				var up: Vector3=points[maxi(0,row-1)*segments+i]-points[mini(row_count,row+1)*segments+i]
				normals[row*segments+i]=up.cross(across).normalized()
		var mesh: ArrayMesh=piece.mesh
		mesh.surface_update_vertex_region(0,0,points.to_byte_array())
		var packed := PackedByteArray();packed.resize(normals.size()*4)
		for i in normals.size():
			var oct: Vector2=normals[i].octahedron_encode()
			packed.encode_u16(i*4,int(clampf(oct.x,0,1)*65535));packed.encode_u16(i*4+2,int(clampf(oct.y,0,1)*65535))
		var offset: int=RenderingServer.mesh_surface_get_format_offset(mesh.surface_get_format(0),points.size(),Mesh.ARRAY_NORMAL)
		mesh.surface_update_vertex_region(0,offset,packed)
		piece.node.set_meta("river_sari_points",points)
