extends MeshInstance3D
## Bounded terrain-following visual soil overlay. Uses existing terrain collision.
func rebuild(generator: Node3D) -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://environment/forest/shaders/ground.gdshader")
	material.set_shader_parameter("soil_roughness", preload("res://environment/forest/assets/textures/forest_ground_04_rough_2k.jpg"))
	material.set_shader_parameter("soil_color", preload("res://environment/forest/assets/textures/forest_ground_04_diff_2k.jpg"))
	material.set_shader_parameter("soil_normal", preload("res://environment/forest/assets/textures/forest_ground_04_nor_gl_2k.jpg"))
	material.set_shader_parameter("grass_color", preload("res://environment/forest/assets/textures/moss_grass_albedo.jpg"))
	material.set_shader_parameter("grass_normal", preload("res://environment/forest/assets/textures/moss_grass_normal.jpg"))
	material.set_shader_parameter("rock_color", preload("res://environment/forest/assets/textures/rock_albedo.jpg"))
	material.set_shader_parameter("rock_normal", preload("res://environment/forest/assets/textures/rock_normal.jpg"))
	material.set_shader_parameter("overlay_cutout", true)
	material.set_shader_parameter("path_point_count", mini(8, generator.path_points.size()))
	var points := PackedVector2Array()
	for i in 8:
		var p: Vector2 = generator.path_points[i] if i < generator.path_points.size() else Vector2.ZERO
		var world: Vector3 = generator.global_transform * Vector3(p.x, 0, p.y)
		points.append(Vector2(world.x, world.z))
	material.set_shader_parameter("path_points", points)
	material.set_shader_parameter("path_radius", generator.config.path_exclusion_radius)
	material.set_shader_parameter("path_feather", generator.config.path_feather)
	material.set_shader_parameter("surface_seed", float(generator.config.seed))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var size: Vector2 = generator.forest_size
	var nx := ceili(size.x)
	var nz := ceili(size.y)
	for x in nx:
		for z in nz:
			for offset in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var p: Vector2 = (Vector2(x, z) + offset) * size / Vector2(nx, nz) - size * 0.5
				var edge := minf(size.x * 0.5 - absf(p.x), size.y * 0.5 - absf(p.y))
				var weight := smoothstep(0.0, 4.0, edge)
				if generator._terrain.has_method("sample_forest_biome_mask"):
					weight *= generator._terrain.call("sample_forest_biome_mask", p.x, p.y)
				surface.set_color(Color(1, 1, 1, weight))
				surface.set_uv(p / 3.2)
				surface.set_normal(generator._normal(p))
				surface.add_vertex(Vector3(p.x, generator._height(p) + 0.045, p.y))
	surface.index()
	surface.generate_tangents()
	surface.set_material(material)
	mesh = surface.commit()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
