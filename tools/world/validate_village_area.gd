extends SceneTree
## Focused construction and terrain checks for the live Bhairavpur addition.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 10:
		await physics_frame
	var settlement: Node3D = world.get_node("Settlement")
	var layout = load("res://world/suryagarh/landscape_layout.gd").new()
	var failures: Array[String] = []
	var names := ["BhairavpurVillageWell", "BhairavpurMarketStall0", "BhairavpurMarketStall1", "BhairavpurKitchenGarden0", "BhairavpurKitchenGarden1"]
	for name in names:
		var node: Node3D = settlement.get_node_or_null(name)
		if node == null:
			failures.append("missing " + name)
			continue
		var grade: float = layout.height(node.global_position.x, node.global_position.z)
		if absf(node.global_position.y - grade) > .02:
			failures.append("grade " + name)
		if node.find_children("*", "CollisionShape3D", true, false).is_empty():
			failures.append("collision " + name)
	var well: Node3D = settlement.get_node_or_null("BhairavpurVillageWell")
	if well != null:
		var mouth: Node3D = well.get_node("DarkWellMouth")
		if mouth.position.y <= .96:
			failures.append("well mouth hidden")
	# The original east-west aisle crosses z=230 from x=-336 to -316.
	var space := world.get_world_3d().direct_space_state
	for x in range(-336, -315, 2):
		var y: float = layout.height(float(x), 230.0)
		var query := PhysicsShapeQueryParameters3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = .35
		capsule.height = 1.8
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, Vector3(float(x), y + .95, 230.0))
		query.collision_mask = 1
		for hit in space.intersect_shape(query, 16):
			var collider: Object = hit.collider
			if collider is Node and well != null and well.is_ancestor_of(collider as Node):
				failures.append("well blocks aisle at x=" + str(x))
	print("VILLAGE AREA ", "PASS" if failures.is_empty() else "FAIL " + str(failures))
	quit(0 if failures.is_empty() else 1)
