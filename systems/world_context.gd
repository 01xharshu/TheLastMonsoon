extends RefCounted
## Resolve ownership during scene installation and removal, without current_scene.
static func find_world(node: Node) -> Node:
	var parent: Node = node
	while is_instance_valid(parent):
		if parent.has_node("GameTimeSystem"):
			return parent
		parent = parent.get_parent()
	return null
