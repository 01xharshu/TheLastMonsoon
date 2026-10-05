extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 3: await physics_frame
	var house = world.get_node("Settlement/BhairavpurHouse9")
	var reasons: Dictionary = {}
	for mesh in house.find_children("*","MeshInstance3D",true,false):
		var ancestor = mesh.get_parent()
		var reason := "static"
		while ancestor != house:
			if ancestor.get_script() != null: reason = str(ancestor.get_script().resource_path); break
			ancestor = ancestor.get_parent()
		if mesh.skin != null: reason += " SKIN"
		if not reasons.has(reason): reasons[reason] = {"count":0,"sample":str(house.get_path_to(mesh))}
		reasons[reason].count += 1
	print("HOUSE MESH REASONS ",reasons)
	var groups: Dictionary = {}
	for mesh in world.find_children("*","GeometryInstance3D",true,false):
		var parts := str(world.get_path_to(mesh)).split("/")
		var label := str(parts[0])+"/"+(str(parts[1]) if parts.size()>1 else "")
		if not groups.has(label): groups[label] = {"geometry_nodes":0,"shadow_nodes":0,"unculled_nodes":0}
		groups[label].geometry_nodes += 1
		if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: groups[label].shadow_nodes += 1
		if mesh.visibility_range_end == 0: groups[label].unculled_nodes += 1
	var ordered: Array = groups.keys()
	ordered.sort_custom(func(a,b): return groups[a].geometry_nodes > groups[b].geometry_nodes)
	var summary: Array = []
	for key in ordered:
		var entry: Dictionary = groups[key].duplicate()
		entry["path"] = key
		summary.append(entry)
	var file := FileAccess.open("res://docs/world/runtime_geometry_audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(summary,"\t")); file.close()
	for index in mini(15,summary.size()): print("GEOMETRY AUDIT ",summary[index])
	world.queue_free()
	for i in 3: await physics_frame
	quit()
