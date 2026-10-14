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
var previous_inputs: PackedVector4Array=[]
var previous_world := Transform3D.IDENTITY
var waist_adjustment:=0.0

func _init(owner: Node3D, skeleton: Skeleton3D,waist_offset_adjustment:float=0.0) -> void:
	actor=owner;rig=skeleton
	waist_adjustment=waist_offset_adjustment
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
		pieces.append({"node":node,"mesh":mesh,"border":border,"rows":row_count,
			"normal_offset":RenderingServer.mesh_surface_get_format_offset(mesh.surface_get_format(0),vertices.size(),Mesh.ARRAY_NORMAL),
			"normal_stride":RenderingServer.mesh_surface_get_format_normal_tangent_stride(mesh.surface_get_format(0),vertices.size())})

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
	var waist := actor.to_local(rig.to_global(pose.origin+delta*Vector3.UP*(float(DIMENSIONS.waist_offset)+waist_adjustment)))
	var pelvis := _point("pelvis")
	var spheres := _capsules()
	var floor_y := 0.0
	var ground: Callable=actor.ground_height
	if ground.is_valid():floor_y=actor.to_local(Vector3(actor.global_position.x,float(ground.call(actor.global_position.x,actor.global_position.z)),actor.global_position.z)).y
	var inputs:=PackedVector4Array([Vector4(waist.x,waist.y,waist.z,floor_y),Vector4(pelvis.x,pelvis.y,pelvis.z,0)])
	inputs.append_array(PackedVector4Array(spheres))
	var terrain_span := 0.0
	if ground.is_valid():
		for offset in [Vector3(.5,0,0),Vector3(-.5,0,0),Vector3(0,0,.5),Vector3(0,0,-.5)]:
			var world := actor.to_global(offset)
			var height:float=float(ground.call(world.x,world.z))
			inputs.append(Vector4(world.x,world.y,world.z,height))
			terrain_span=maxf(terrain_span,absf(actor.to_local(Vector3(world.x,height,world.z)).y-floor_y))
	# Seated gestures move arms/head without changing this lower-fabric
	# envelope. Reuse exact geometry only while every input is unchanged.
	if inputs==previous_inputs and actor.global_transform==previous_world:return
	previous_inputs=inputs;previous_world=actor.global_transform
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
			if row==0:continue # The sewn waist stays at the waist, rather than enclosing the knees.
			var vertical: float=maxf(0.0,absf(sphere.y-y)-band)
			if vertical>=sphere.w:continue
			sections.append(Vector3(sphere.x-waist.x,sphere.z-waist.z,sqrt(maxf(0.0,sphere.w*sphere.w-vertical*vertical))+float(DIMENSIONS.clearance)))
		var hip_vertical: float=maxf(0.0,absf(pelvis.y-y)-band)
		var hip_scale: float=sqrt(maxf(0.0,1.0-pow(hip_vertical/float(DIMENSIONS.pelvis_height),2)))
		for j in PLANE_COUNT:
			var normal: Vector2=planes[j]
			var ex:float=rx*normal.x;var ez:float=rz*normal.y
			var extent: float=sqrt(ex*ex+ez*ez)
			for section in sections:
				extent=maxf(extent,normal.x*section.x+normal.y*section.y+section.z)
			if hip_vertical<float(DIMENSIONS.pelvis_height):
				var hx:float=float(DIMENSIONS.pelvis_rx)*normal.x;var hz:float=float(DIMENSIONS.pelvis_ry)*normal.y
				var hip_extent: float=sqrt(hx*hx+hz*hz)*hip_scale
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
			# Keep a local packed row: nested writes can copy the shared
			# packed array for every single vertex.
			var current:PackedFloat32Array=radii[row]
			var above:PackedFloat32Array=radii[row-1]
			var below:PackedFloat32Array=radii[row+1]
			for i in segments:current[i]=maxf(current[i],(above[i]+below[i])*.5)
			radii[row]=current
	var hem_heights := PackedFloat32Array();hem_heights.resize(segments)
	for i in segments:
		var point := Vector3(waist.x+directions[i].x*radii[rings][i],0,waist.z+directions[i].y*radii[rings][i])
		hem_heights[i]=floor_y+.018
		if ground.is_valid():
			var world := actor.to_global(point)
			hem_heights[i]=actor.to_local(Vector3(world.x,float(ground.call(world.x,world.z)),world.z)).y+.018
	var seated:float=1.0-smoothstep(.40,.65,waist.y-floor_y)
	# A local grid rejects spheres whose horizontal bound cannot reach a
	# cloth vertex. It changes only candidate selection, not the envelope.
	var lap_cells: Dictionary={}
	if seated>0:
		for sphere in spheres:
			var radius:float=sphere.w+float(DIMENSIONS.clearance)+.016
			var bound:=Vector4(sphere.x,sphere.y,sphere.z,radius*radius)
			for x in range(floori((sphere.x-radius)*8),floori((sphere.x+radius)*8)+1):
				for z in range(floori((sphere.z-radius)*8),floori((sphere.z+radius)*8)+1):
					var cell:=Vector2i(x,z)
					if not lap_cells.has(cell):lap_cells[cell]=[]
					lap_cells[cell].append(bound)
	var drape := PackedVector3Array();drape.resize((rings+1)*segments)
	var spread:=PackedFloat32Array();spread.resize(segments)
	for i in segments:
		for row in rings+1:spread[i]=maxf(spread[i],radii[row][i])
	for row in rings+1:
		var t := float(row)/rings
		for i in segments:
			var direction: Vector2=directions[i]
			# Seated cloth runs across the lap before falling towards the feet.
			# Reusing horizontal standing sections made the first ring jump
			# outside both knees, leaving a rigid raised rim around the lap.
			var radius:float=lerpf(radii[row][i],lerpf(radii[0][i],spread[i],t),seated)
			var point := Vector3(waist.x+direction.x*radius,0,waist.z+direction.y*radius)
			point.y=lerpf(waist.y,hem_heights[i],t)
			if row>0 and seated>0:
				var lap_top:float=point.y
				for sphere: Vector4 in lap_cells.get(Vector2i(floori(point.x*8),floori(point.z*8)),[]):
					var dx:float=point.x-sphere.x
					var dz:float=point.z-sphere.z
					var distance_squared:float=dx*dx+dz*dz
					if distance_squared<sphere.w:
						lap_top=maxf(lap_top,sphere.y+sqrt(sphere.w-distance_squared)+.008)
				point.y=lerpf(point.y,lap_top,seated)
			drape[row*segments+i]=point
	# Spread lap folds across neighbouring samples without lowering a point
	# into its leg envelope. The sewn waist remains fixed.
	if seated>0:
		for sweep in 2:
			var previous:=drape.duplicate()
			for row in range(1,rings+1):
				for i in segments:
					var index:int=row*segments+i
					var angular:float=(previous[row*segments+(i+segments-1)%segments].y+previous[row*segments+(i+1)%segments].y)*.5
					var radial:float=previous[index].y
					if row<rings:radial=(previous[index-segments].y+previous[index+segments].y)*.5
					drape[index].y=maxf(previous[index].y,maxf(angular,radial))
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
		# Godot generates tangents for a surface with normals. Its packed
		# normal/tangent records are interleaved, even without ARRAY_TANGENT
		# in the original arrays. Use the actual renderer stride.
		var stride:int=piece.normal_stride
		var packed := PackedByteArray();packed.resize(normals.size()*stride)
		for i in normals.size():
			var oct: Vector2=normals[i].octahedron_encode()
			packed.encode_u16(i*stride,int(clampf(oct.x,0,1)*65535));packed.encode_u16(i*stride+2,int(clampf(oct.y,0,1)*65535))
			if stride>=8:
				var normal:Vector3=normals[i]
				var tangent:Vector3=Vector3(normal.z,-normal.x,normal.y).cross(normal).normalized()
				var tangent_oct:Vector2=tangent.octahedron_encode()
				tangent_oct.y=maxf(tangent_oct.y,1.0/32767.0)*.5+.5
				var tx:int=int(clampf(tangent_oct.x,0,1)*65535)
				var ty:int=int(clampf(tangent_oct.y,0,1)*65535)
				if tx==0 and ty==65535:tx=65535
				packed.encode_u16(i*stride+4,tx);packed.encode_u16(i*stride+6,ty)
		mesh.surface_update_vertex_region(0,piece.normal_offset,packed)
		piece.node.set_meta("river_sari_points",points)
