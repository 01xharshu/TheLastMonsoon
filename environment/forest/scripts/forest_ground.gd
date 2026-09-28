@tool
extends MeshInstance3D
## Keeps the benchmark ground path visible while sharing the generator's mask.
@export var generator_path: NodePath = NodePath("../../ForestGenerator")

func _ready() -> void:
	var generator := get_node_or_null(generator_path)
	if generator == null: return
	if generator.has_signal("generated"):
		generator.generated.connect(_sync_material)
	_sync_material()

func _sync_material() -> void:
	var generator := get_node_or_null(generator_path)
	if generator == null or generator.config == null: return
	var material := get_active_material(0) as ShaderMaterial
	if material == null: return
	var points := PackedVector2Array()
	for i in 8:
		points.append(generator.path_points[i] if i < generator.path_points.size() else Vector2.ZERO)
	material.set_shader_parameter("path_points", points)
	material.set_shader_parameter("path_point_count", mini(generator.path_points.size(), 8))
	material.set_shader_parameter("path_radius", generator.config.path_exclusion_radius)
	material.set_shader_parameter("path_feather", generator.config.path_feather)
	material.set_shader_parameter("surface_seed", float(generator.config.seed))
