extends Node3D
## Secluded, walkable forest shrine. All geometry is original and deterministic.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const TREE = preload("res://assets/nature/models/island_tree_02.glb")
const CENTRE := Vector2(620.0, -198.0)
var layout = Layout.new()
var rng := RandomNumberGenerator.new()
var stone: StandardMaterial3D
var dark_stone: StandardMaterial3D

func _ready() -> void:
	rng.seed = 18570924
	stone = material(Color(0.36, 0.34, 0.30), 0.94)
	dark_stone = material(Color(0.19, 0.19, 0.17), 1.0)
	build_forest()
	build_cave()
	build_idol()

func material(tint: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = load("res://assets/nature/materials/rock_boulder_dry_diff_1k.jpg")
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func part(name: String, mesh: PrimitiveMesh, pos: Vector3, mat: Material, collide: bool = true) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = name
	visual.mesh = mesh
	visual.material_override = mat
	visual.position = pos
	add_child(visual)
	if collide:
		visual.create_trimesh_collision()
	return visual

func ellipsoid(name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	var visual := part(name, mesh, pos, mat, false)
	visual.scale = size

func build_forest() -> void:
	var source: Node3D = TREE.instantiate()
	var mesh: Mesh
	for child in source.find_children("*", "MeshInstance3D", true, false):
		mesh = (child as MeshInstance3D).mesh
		break
	if mesh == null:
		push_error("Forest tree mesh missing")
		return
	var transforms: Array[Transform3D] = []
	for i in 850:
		var p := CENTRE + Vector2(rng.randf_range(-155.0, 155.0), rng.randf_range(-165.0, 160.0))
		if absf(p.x) > Layout.HALF - 15 or absf(p.y) > Layout.HALF - 15: continue
		var distance := p.distance_to(CENTRE)
		if distance > 160 or layout.normal(p.x, p.y).y < 0.70: continue
		# Maintain a readable footpath to the cave and a clear chamber/shaft.
		if absf(p.x - CENTRE.x) < 7.0 and p.y > -152.0 and p.y < -120.0: continue
		var mouth := cave_centre(0.0)
		if p.distance_to(mouth) < 14.0 or layout.plot_clearance(p.x, p.y) < 60.0: continue
		var scale := rng.randf_range(1.6, 3.5)
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(scale, scale * rng.randf_range(0.85, 1.2), scale))
		transforms.append(Transform3D(basis, Vector3(p.x, layout.height(p.x, p.y) - 0.1, p.y)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size(): mm.set_instance_transform(i, transforms[i])
	var grove := MultiMeshInstance3D.new()
	grove.name = "SecludedBroadleafForest"
	grove.multimesh = mm
	grove.visibility_range_end = 550.0
	add_child(grove)
	set_meta("new_forest_trees", transforms.size())
	source.free()

func cave_centre(t: float) -> Vector2:
	return Vector2(CENTRE.x + 28.0 * smoothstep(0.20, 0.84, t), lerpf(-150.0, -230.0, t))

func cave_floor(t: float) -> float:
	return lerpf(73.5, 76.0, t)

func cave_profile(t: float) -> Vector2:
	var chamber_blend := smoothstep(0.55, 0.92, t)
	return Vector2(lerpf(4.8, 15.0, chamber_blend), lerpf(6.4, 17.0, chamber_blend))

func build_cave() -> void:
	# A single watertight-looking half-tube, sampled densely enough that the
	# natural variation is in the silhouette rather than repeated rock props.
	var entrance_z := -150.0
	var rear_z := -230.0
	var rings := 46
	var slices := 28
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for ring in rings + 1:
		var t := float(ring) / float(rings)
		var centre := cave_centre(t)
		var tangent := (cave_centre(minf(1.0, t + 0.002)) - cave_centre(maxf(0.0, t - 0.002))).normalized()
		var across := Vector2(-tangent.y, tangent.x)
		var floor_y := cave_floor(t)
		var profile := cave_profile(t)
		for side in 2:
			for j in slices + 1:
				var angle := PI * float(j) / float(slices)
				var wave := 0.38 * sin(t * 25.0 + angle * 9.0) + 0.28 * sin(t * 57.0 - angle * 14.0)
				var radial := 1.0 + wave / profile.x
				var offset := 2.8 if side == 1 else 0.0
				var planar := centre + across * (profile.x + offset) * cos(angle) * radial
				var y := floor_y + (profile.y + offset) * sin(angle) * radial
				vertices.append(Vector3(planar.x, y, planar.y))
				uvs.append(Vector2(float(j) / 5.0, t * 11.0))
	for side in 2:
		for ring in rings:
			for j in slices:
				var start := side * (rings + 1) * (slices + 1)
				var a := start + ring * (slices + 1) + j
				var b := a + slices + 1
				var roof_hole := ring > 33 and ring < 41 and j >= 12 and j < 16
				if roof_hole: continue
				if side == 0:
					indices.append_array(PackedInt32Array([a, b, a + 1, b, b + 1, a + 1]))
				else:
					indices.append_array(PackedInt32Array([a, a + 1, b, b, a + 1, b + 1]))
	# Front and rear stone lips connect the inside to the outside skin.
	for ring in [0, rings]:
		for j in slices:
			var inner: int = ring * (slices + 1) + j
			var outer: int = (rings + 1) * (slices + 1) + inner
			indices.append_array(PackedInt32Array([inner, inner + 1, outer, outer, inner + 1, outer + 1]))
	# Separate triangles create a narrow light well at the chamber's far end.
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := SurfaceTool.new()
	surface.create_from(mesh, 0)
	surface.generate_normals()
	mesh = surface.commit()
	var cave := MeshInstance3D.new()
	cave.name = "ContinuousRockPassage"
	cave.mesh = mesh
	var rock_shader := ShaderMaterial.new()
	rock_shader.shader = load("res://world/suryagarh/shaders/cave_rock.gdshader")
	rock_shader.set_shader_parameter("rock_albedo", load("res://assets/nature/materials/rock_boulder_dry_diff_1k.jpg"))
	cave.material_override = rock_shader
	add_child(cave)
	cave.create_trimesh_collision()
	var floor_surface := SurfaceTool.new()
	floor_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in 46:
		var t0 := float(step) / 46.0
		var t1 := float(step + 1) / 46.0
		var points: Array[Vector3] = []
		for t in [t0, t1]:
			var center := cave_centre(t)
			var tangent := (cave_centre(minf(1.0,t+0.002)) - cave_centre(maxf(0.0,t-0.002))).normalized()
			var across := Vector2(-tangent.y,tangent.x)
			for side in [-1.0,1.0]:
				var planar: Vector2 = center + across * (cave_profile(t).x + 0.25) * side
				points.append(Vector3(planar.x,cave_floor(t)-0.08,planar.y))
		for index in [0,1,2,1,3,2]:
			floor_surface.set_uv(Vector2(points[index].x/4.0,points[index].z/4.0))
			floor_surface.add_vertex(points[index])
	floor_surface.generate_normals()
	var cave_floor_mesh := MeshInstance3D.new()
	cave_floor_mesh.name = "StoneFloor"
	cave_floor_mesh.mesh = floor_surface.commit()
	cave_floor_mesh.material_override = cave.material_override
	add_child(cave_floor_mesh)
	cave_floor_mesh.create_trimesh_collision()
	# A single back wall encloses the chamber and gives the idol a dark ground.
	var rear_point := cave_centre(1.0)
	var rear_y := cave_floor(1.0)
	var rear_mesh := SurfaceTool.new()
	rear_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rear_profile := cave_profile(1.0)
	for j in 28:
		var a := PI * float(j) / 28.0
		var b := PI * float(j + 1) / 28.0
		for vertex in [Vector3(rear_point.x, rear_y + 1.0, rear_point.y - 1.0),
			Vector3(rear_point.x + rear_profile.x * cos(a), rear_y + rear_profile.y * sin(a), rear_point.y - 1.0),
			Vector3(rear_point.x + rear_profile.x * cos(b), rear_y + rear_profile.y * sin(b), rear_point.y - 1.0)]:
			rear_mesh.set_uv(Vector2(vertex.x / 3.5, vertex.y / 3.5))
			rear_mesh.add_vertex(vertex)
	rear_mesh.generate_normals()
	var rear_wall := MeshInstance3D.new()
	rear_wall.name = "ChamberBedrock"
	rear_wall.mesh = rear_mesh.commit()
	rear_wall.material_override = cave.material_override
	add_child(rear_wall)
	rear_wall.create_trimesh_collision()
	# The aperture is cut from only a short roof span; the rest is solid stone.
	# Use a naturally irregular hole in the shell rather than opening the
	# whole chamber to the sky.
	var shaft := SpotLight3D.new()
	shaft.name = "DaylightShaft"
	shaft.position = Vector3(rear_point.x, rear_y + 17.0, rear_point.y + 10.0)
	shaft.rotation_degrees.x = -90.0
	shaft.spot_range = 32.0
	shaft.spot_angle = 25.0
	shaft.light_energy = 3.0
	shaft.light_color = Color(1.0, 0.88, 0.7)
	shaft.shadow_enabled = true
	add_child(shaft)
	var bounce := OmniLight3D.new()
	bounce.name = "StoneBounce"
	bounce.position = Vector3(rear_point.x, rear_y + 9.0, rear_point.y + 11.0)
	bounce.omni_range = 18.0
	bounce.light_energy = 1.15
	bounce.light_color = Color(1.0, 0.83, 0.61)
	add_child(bounce)
	set_meta("entrance", Vector3(CENTRE.x, cave_floor(0.0), entrance_z))

func build_idol() -> void:
	var p := cave_centre(0.88)
	var floor_y := cave_floor(0.88)
	var base := BoxMesh.new()
	base.size = Vector3(8.0, 1.1, 6.0)
	part("StonePlinth", base, Vector3(p.x, floor_y + 0.55, p.y), dark_stone)
	var c := Vector3(p.x, floor_y + 1.1, p.y)
	ellipsoid("SeatedBody", c + Vector3(0, 3.1, 0), Vector3(2.25, 2.75, 1.65), stone)
	ellipsoid("LeftKnee", c + Vector3(-2.15, 1.15, 0.7), Vector3(1.65, 1.05, 1.1), stone)
	ellipsoid("RightKnee", c + Vector3(2.15, 1.15, 0.7), Vector3(1.65, 1.05, 1.1), stone)
	ellipsoid("ElephantHead", c + Vector3(0, 6.3, 0.5), Vector3(1.7, 1.85, 1.45), stone)
	for side in [-1.0, 1.0]:
		ellipsoid("FanEar", c + Vector3(side * 1.85, 6.25, 0.45), Vector3(1.08, 1.5, 0.42), stone)
		ellipsoid("UpperArm", c + Vector3(side * 2.5, 4.8, 0), Vector3(0.48, 1.65, 0.52), stone)
		ellipsoid("LowerArm", c + Vector3(side * 2.85, 2.8, 0.9), Vector3(0.56, 1.25, 0.56), stone)
		ellipsoid("Tusk", c + Vector3(side * 0.82, 5.6, 1.75), Vector3(0.22, 0.68, 0.22), material(Color(0.59, 0.56, 0.48), 0.95))
	for i in 5:
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.55 - i * 0.075
		trunk.bottom_radius = 0.58 - i * 0.075
		trunk.height = 0.9
		trunk.radial_segments = 16
		part("CurvedTrunk", trunk, c + Vector3(0.1 + i * 0.15, 5.55 - i * 0.68, 1.5 + i * 0.16), stone, false)
	var crown := CylinderMesh.new()
	crown.top_radius = 0.9
	crown.bottom_radius = 1.45
	crown.height = 1.7
	crown.radial_segments = 16
	part("CarvedCrown", crown, c + Vector3(0, 8.55, 0.25), stone, false)
	set_meta("idol_status", "Original procedural stone blockout; sculpture and devotional visual review pending")
