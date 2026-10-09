extends Node3D
## Bounded ambient flocks. Shared silhouettes, no physics, no per-bird processing.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const FLOCK_COUNT := 12
const BIRDS_PER_FLOCK := 5
var birds: Array[Node3D] = []
var wings: Array[Node3D] = []
var elapsed := 0.0
var flight_heights := PackedFloat32Array()
var layout := Layout.new()
var game_time: GameTimeSystem
var bird_material: StandardMaterial3D
var activity := 1.0
var last_clock_minutes := -INF

func _ready() -> void:
	name = "SkyBirds"
	game_time = get_parent().get_node_or_null("GameTimeSystem") as GameTimeSystem
	var material := StandardMaterial3D.new()
	bird_material = material
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.11, 0.095, 0.08)
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := _mesh([Vector3(0,0,-0.42),Vector3(-0.09,0,0.12),Vector3(0,0.09,0.05),Vector3(0.09,0,0.12),Vector3(0,0,0.34)], [0,1,2,0,2,3,1,4,3], material)
	var wing := _mesh([Vector3.ZERO,Vector3(0.29,0,-0.15),Vector3(0.76,0,0.09),Vector3(0.55,0,0.22),Vector3(0.12,0,0.18)], [0,1,2,0,2,3,0,3,4], material)
	for i in range(FLOCK_COUNT * BIRDS_PER_FLOCK):
		var bird := Node3D.new()
		add_child(bird)
		birds.append(bird)
		_add_mesh(bird, body)
		for side in [-1.0, 1.0]:
			var pivot := Node3D.new()
			bird.add_child(pivot)
			pivot.scale.x = side
			_add_mesh(pivot, wing)
			wings.append(pivot)
	# Sample the complete orbit once: smooth constant flight height, no terrain queries per frame.
	for flock in range(FLOCK_COUNT):
		var center := _flock_center(flock)
		var radius := 95.0 + float(flock % 3) * 27.0
		var highest := maxf(layout.height(center.x, center.y), 12.0)
		for sample_index in range(96):
			var angle := float(sample_index) / 96.0 * TAU
			for offset in [0.0, 4.0]:
				var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius + offset)
				highest = maxf(highest, layout.height(point.x, point.y))
		flight_heights.append(highest + 38.0 + float(flock % 4) * 8.0)
	_update_activity()
	_update_birds()

func _mesh(vertices: Array[Vector3], indices: Array[int], material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		surface.add_vertex(vertices[index])
	surface.generate_normals()
	var result := surface.commit()
	result.surface_set_material(0, material)
	return result

func _add_mesh(parent: Node3D, mesh: Mesh) -> void:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.visibility_range_end = 650.0
	parent.add_child(visual)

func _process(delta: float) -> void:
	_update_activity()
	if not visible: return
	elapsed += delta
	_update_birds()

func _update_activity() -> void:
	if game_time == null: return
	if game_time.total_game_minutes == last_clock_minutes: return
	last_clock_minutes = game_time.total_game_minutes
	var elevation := sin((game_time.get_time_of_day_fraction() - 0.25) * TAU)
	activity = smoothstep(-0.12, 0.08, elevation)
	visible = activity > 0.001
	bird_material.albedo_color.a = activity

func _flock_center(flock: int) -> Vector2:
	# Keep a few routes near open player approaches rather than only a distant grid.
	if flock == 0: return Vector2(-440, -200)
	if flock == 4: return Vector2(-230, 180)
	if flock == 5: return Vector2(12, 155)
	return Vector2(-620.0 + float(flock % 4) * 410.0, -580.0 + float(flock / 4) * 530.0)

func _update_birds() -> void:
	for i in range(birds.size()):
		var flock := i / BIRDS_PER_FLOCK
		var member := i % BIRDS_PER_FLOCK
		var center := _flock_center(flock)
		var radius := 95.0 + float(flock % 3) * 27.0
		var angle := elapsed * (0.055 + float(flock % 3) * 0.008) + float(flock) * 1.7 - float(member) * 0.055
		var horizontal := center + Vector2(cos(angle), sin(angle)) * (radius + float(member % 2) * 4.0)
		var bird := birds[i]
		bird.position = Vector3(horizontal.x, flight_heights[flock] + sin(angle * 2.0 + float(member)) * 2.0, horizontal.y)
		# Local -Z faces the continuous tangent; banking follows the turn.
		bird.rotation = Vector3(0.0, PI - angle, -0.12)
		var phase := elapsed * 13.0 + float(i) * 1.31
		var glide := smoothstep(0.2, 0.6, sin(elapsed * 0.43 + float(i)))
		var flap := lerpf(sin(phase) * 0.62, 0.08, glide)
		wings[i * 2].rotation.z = -flap
		wings[i * 2 + 1].rotation.z = flap
