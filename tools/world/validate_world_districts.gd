extends SceneTree
const Districts = preload("res://world/suryagarh/world_districts.gd")
const Budget = preload("res://systems/simulation_budget.gd")
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func run() -> void:
	check(Districts.district_at(Vector3(-332, 7, 232)) == "village", "village footprint")
	check(Districts.district_at(Vector3(-330, 8, -415)) == "city", "city footprint")
	check(Districts.district_at(Vector3(320, 10, 120)) == "police", "station story destination")
	check(Districts.district_at(Vector3(0, 0, 165)) == "countryside", "connecting journey outside settlements")
	for road: String in Districts.Layout.ROUTES:
		if road.begins_with("city_"): check(Districts.road_district(road) == "city", road)
		if road.begins_with("village_"): check(Districts.road_district(road) == "village", road)
	var world := Node3D.new(); root.add_child(world)
	var districts := Districts.new(); world.add_child(districts)
	check(districts.has_node("Village") and districts.has_node("City"), "separate district manifests installed")
	var viewer := Node3D.new(); world.add_child(viewer)
	var subject := Node3D.new(); subject.position.x = 500; world.add_child(subject)
	var camera := Camera3D.new(); camera.position.x = 500; world.add_child(camera); camera.current = true
	check(Budget.interval(subject, viewer) == 0.5, "ordinary distant population remains budgeted")
	viewer.set_meta("story_cinematic", true)
	check(Budget.interval(subject, viewer) == 0, "cinematic area immediately receives full simulation")
	subject.position.x = 0
	check(Budget.interval(subject, viewer) == 0, "player proximity remains responsive")
	subject.position.x = 250
	check(Budget.interval(subject, viewer, true) == 0, "mission/combat essential override")
	viewer.set_meta("story_cinematic", false)
	check(Budget.interval(subject, viewer) == 0.5, "normal tiers restored after cinematic")
	world.queue_free(); await process_frame
	print("WORLD DISTRICTS ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
