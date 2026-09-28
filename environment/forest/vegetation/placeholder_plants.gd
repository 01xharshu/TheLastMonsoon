class_name ForestPlaceholderPlants
extends RefCounted
## Low-poly stand-ins with leaf/grass silhouettes. Replace meshes with Blender LODs.
const FOLIAGE_SHADER = preload("res://environment/forest/shaders/foliage.gdshader")

static func make_cluster(count: int, height: float, width: float, lean: float, tint: Color, wind: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var angle := TAU * float(i) / float(count) + 0.37 * sin(float(i) * 2.7)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var right := Vector3(-direction.z, 0.0, direction.x)
		var length_factor := 0.79 + 0.21 * (0.5 + 0.5 * sin(float(i) * 7.13))
		var leaf_height := height * length_factor
		var variation := 0.82 + 0.18 * sin(float(i) * 3.91)
		var color := Color(tint.r * variation, tint.g * variation, tint.b * variation, 1.0)
		var base := Vector3(direction.x * 0.04, 0.015, direction.z * 0.04)
		var mid := direction * (lean * 0.45) + Vector3.UP * leaf_height * 0.54
		var tip := direction * lean + Vector3.UP * leaf_height
		var half_width := width * (0.7 + 0.3 * variation) * 0.5
		var vertices := [base - right * half_width * 0.28, base + right * half_width * 0.28,
			mid - right * half_width, mid + right * half_width, tip]
		var uvs := [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 0.55), Vector2(1.0, 0.55), Vector2(0.5, 1.0)]
		for triangle in [[0, 1, 2], [1, 3, 2], [2, 3, 4]]:
			for index in triangle:
				surface.set_color(color)
				surface.set_uv(uvs[index])
				surface.set_normal(Vector3.UP.lerp(direction, 0.18).normalized())
				surface.add_vertex(vertices[index])
	var material := ShaderMaterial.new()
	material.shader = FOLIAGE_SHADER
	material.set_shader_parameter("wind_strength", wind)
	surface.set_material(material)
	return surface.commit()
