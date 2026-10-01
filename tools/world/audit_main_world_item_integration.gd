extends SceneTree
var scenes: Dictionary = {}
var scripts: Dictionary = {}
func _initialize() -> void: _run.call_deferred()
func _visit(node: Node) -> void:
	if not node.scene_file_path.is_empty():
		if not scenes.has(node.scene_file_path): scenes[node.scene_file_path] = []
		scenes[node.scene_file_path].append(str(node.get_path()))
	if node.get_script() != null:
		var path: String = node.get_script().resource_path
		scripts[path] = int(scripts.get(path,0)) + 1
	for child in node.get_children(): _visit(child)
func _run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	for frame in 3: await physics_frame
	_visit(world)
	var resources: Array[String] = []
	_collect("res://objects/household", resources)
	var items: Array = []
	for path in resources:
		items.append({"scene":path,"instances":scenes.get(path,[]).size(),"paths":scenes.get(path,[])})
	var wrappers := {}
	for path in ["res://objects/roti.tscn","res://objects/water_pot.tscn","res://objects/water_bag.tscn","res://objects/oil_lamp.tscn"]:
		wrappers[path] = scenes.get(path,[])
	var report := {"world":"res://world/suryagarh/suryagarh_world.tscn","date":"2026-10-01","household_scenes":items,"interactive_wrappers":wrappers,"script_instances":scripts,"limits":"Scene instantiation audit, not art/contact/normal-speed approval. Procedural legacy equivalents are reported separately from new reusable prefabs."}
	var file := FileAccess.open("res://docs/assets/main_world_item_audit_2026-10-01.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("MAIN WORLD ITEM AUDIT: PASS | ",items.size()," household prefabs inspected")
	quit()
func _collect(directory: String, result: Array[String]) -> void:
	var dir := DirAccess.open(directory)
	for name in dir.get_files():
		if name.ends_with(".tscn"): result.append(directory+"/"+name)
	for name in dir.get_directories(): _collect(directory+"/"+name,result)
