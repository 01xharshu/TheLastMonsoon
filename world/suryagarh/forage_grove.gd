extends Node3D
## Small, reachable fruit patch beside the Bhairavpur approach.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const Mango = preload("res://objects/mango.gd")
const GROVE_CENTRES: Array[Vector2] = [Vector2(-240, 176), Vector2(-246, 186)]
var collected_ids: Array[String] = []
func _ready() -> void:
	add_to_group("forage_groves")
	var layout := Layout.new()
	for grove_index in GROVE_CENTRES.size():
		var centre := GROVE_CENTRES[grove_index]
		var tree = preload("res://environment/vegetation/mango_tree/mango_tree_01.glb").instantiate()
		add_child(tree)
		tree.position = Vector3(centre.x, layout.height(centre.x, centre.y), centre.y)
		for i in 5:
			var p: Vector2 = centre + Vector2(cos(i * 1.25), sin(i * 1.25)) * (1.5 + i * 0.25)
			var fruit := Mango.new()
			fruit.forage_id = "bhairavpur_mango_%d_%d" % [grove_index, i]
			fruit.harvested.connect(_record_collection)
			add_child(fruit)
			fruit.position = Vector3(p.x, layout.height(p.x, p.y) + 0.15, p.y)
	# Resolve against the actual baked collision surface, which may differ from
	# the layout source while another terrain bake is in progress.
	await get_tree().physics_frame
	for child in get_children():
		if not child is Interactable or child.is_queued_for_deletion(): continue
		var query := PhysicsRayQueryParameters3D.create(child.global_position + Vector3.UP * 5.0, child.global_position + Vector3.DOWN * 12.0)
		query.exclude = [child.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): child.global_position = hit.position + Vector3.UP * 0.135

func _record_collection(forage_id: String) -> void:
	if not forage_id.is_empty() and not forage_id in collected_ids:
		collected_ids.append(forage_id)

func restore_collected(ids: Array) -> void:
	# Record unavailable historical IDs too; adding/repositioning fruit must
	# not erase harvest history from the next save.
	for id in ids:
		if id is String and id.begins_with("bhairavpur_mango_"):
			_record_collection(id)
	for child in get_children():
		if child.get_script() == Mango and child.forage_id in collected_ids:
			child.collected = true
			child.queue_free()
