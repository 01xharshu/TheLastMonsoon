extends SceneTree
## Compare accelerated garment clearance against the previous exhaustive cell search.
const Clearance = preload("res://vehicles/coachman_clearance.gd")
const Humans = preload("res://characters/human_scene.gd")
class Holder extends Node3D:
	var _skeleton: Skeleton3D
var failed := false

func _initialize() -> void:
	_run.call_deferred()

func legacy_nearest(clearance, at: Vector3) -> Dictionary:
	var cell: Vector3i = clearance._cell(at)
	var distance := INF
	var result: Dictionary = {}
	var visited: Dictionary = {}
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				for id in clearance.cells.get(cell + Vector3i(x,y,z), []):
					if visited.has(id): continue
					visited[id] = true
					var triangle: Dictionary = clearance.triangles[id]
					var point := Clearance.closest(at,triangle.a,triangle.b,triangle.c)
					var squared := point.distance_squared_to(at)
					if squared < distance:
						distance = squared
						result = {"distance":sqrt(squared), "signed":(at-point).dot(triangle.normal), "point":point, "normal":triangle.normal}
	return result

func _run() -> void:
	var coach := Node3D.new()
	root.add_child(coach)
	var actor := Holder.new()
	coach.add_child(actor)
	var figure := Humans.instantiate("res://characters/npcs/motion/village_farmer/village_farmer_rigged_candidate.glb")
	actor.add_child(figure)
	actor._skeleton = figure.find_children("*", "Skeleton3D", true, false)[0]
	var clearance := Clearance.new()
	clearance.build_body(actor,coach)
	assert(not clearance.triangles.is_empty())
	var random := RandomNumberGenerator.new()
	random.seed = 1857
	var points: Array[Vector3] = []
	for index in 128:
		var triangle: Dictionary = clearance.triangles[random.randi_range(0,clearance.triangles.size()-1)]
		var center: Vector3 = (triangle.a+triangle.b+triangle.c)/3.0
		points.append(center+Vector3(random.randf_range(-.15,.15),random.randf_range(-.15,.15),random.randf_range(-.15,.15)))
	var previous: Array[Dictionary] = []
	var started := Time.get_ticks_usec()
	for point in points: previous.append(legacy_nearest(clearance,point))
	var legacy_usec := Time.get_ticks_usec()-started
	started = Time.get_ticks_usec()
	for index in points.size():
		var result: Dictionary = clearance.nearest(points[index])
		if result != previous[index]:
			failed = true
			push_error("Garment clearance contact changed at sample " + str(index))
	var optimized_usec := Time.get_ticks_usec()-started
	coach.free()
	print("COACHMAN CLEARANCE ", "FAIL" if failed else "PASS", " | 128 exact contact comparisons | previous_us=", legacy_usec, " current_us=", optimized_usec)
	var saves := root.get_node_or_null("SaveManager")
	if saves != null: saves.quit_game(1 if failed else 0)
	else: quit(1 if failed else 0)
