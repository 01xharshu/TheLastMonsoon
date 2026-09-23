extends Node3D
## Small, reachable fruit patch beside the Bhairavpur approach.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const Mango = preload("res://objects/mango.gd")
func _ready() -> void:
	var layout := Layout.new()
	for centre in [Vector2(-240, 176), Vector2(-246, 186)]:
		var tree = preload("res://environment/vegetation/mango_tree/mango_tree_01.glb").instantiate()
		add_child(tree)
		tree.position = Vector3(centre.x, layout.height(centre.x, centre.y), centre.y)
		for i in 5:
			var p: Vector2 = centre + Vector2(cos(i * 1.25), sin(i * 1.25)) * (1.5 + i * 0.25)
			var fruit := Mango.new()
			add_child(fruit)
			fruit.position = Vector3(p.x, layout.height(p.x, p.y) + 0.15, p.y)
	# Resolve against the actual baked collision surface, which may differ from
	# the layout source while another terrain bake is in progress.
	await get_tree().physics_frame
	for child in get_children():
		if not child is Interactable: continue
		var query := PhysicsRayQueryParameters3D.create(child.global_position + Vector3.UP * 5.0, child.global_position + Vector3.DOWN * 12.0)
		query.exclude = [child.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): child.global_position = hit.position + Vector3.UP * 0.135
