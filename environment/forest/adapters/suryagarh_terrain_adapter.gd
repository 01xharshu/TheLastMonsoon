extends Node
## Map-specific bridge. The forest generator itself remains portable.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
var layout = Layout.new()

func _world_point(x: float, z: float) -> Vector2:
	var origin: Vector3 = get_parent().global_position
	return Vector2(origin.x + x, origin.z + z)

func sample_forest_height(x: float, z: float) -> float:
	var p := _world_point(x, z)
	return layout.height(p.x, p.y) - get_parent().global_position.y

func sample_forest_normal(x: float, z: float) -> Vector3:
	var p := _world_point(x, z)
	return layout.normal(p.x, p.y)

func sample_forest_biome_mask(x: float, z: float) -> float:
	var p := _world_point(x, z)
	if layout.built_area(p.x, p.y): return 0.0
	var road := smoothstep(6.0, 16.0, layout.road_distance(p.x, p.y))
	var plot := smoothstep(15.0, 40.0, layout.plot_clearance(p.x, p.y))
	var field := 1.0 - layout.field_mask(p.x, p.y)
	return road * plot * field

func sample_forest_existing_tree_points() -> PackedVector2Array:
	var result := PackedVector2Array()
	var landscape := get_node_or_null("../../Landscape")
	if landscape == null: return result
	var nature := landscape.get_node_or_null("NatureTiles")
	if nature == null: return result
	var origin: Vector3 = get_parent().global_position
	var size: Vector2 = get_parent().forest_size
	for tile in nature.get_children():
		if absf(tile.global_position.x - origin.x) > 190.0 or absf(tile.global_position.z - origin.z) > 190.0: continue
		for body in tile.get_children():
			if not body is StaticBody3D: continue
			var collision := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if collision == null or not collision.shape is CylinderShape3D: continue
			var p: Vector3 = body.global_position
			var local := Vector2(p.x - origin.x, p.z - origin.z)
			if absf(local.x) < size.x * 0.5 + 5.0 and absf(local.y) < size.y * 0.5 + 5.0:
				result.append(local)
	return result
