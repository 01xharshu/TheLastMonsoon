extends SceneTree
class SurveyWorld extends Node3D:
	func move_to_review_point(_index: int) -> void: pass
class TutorialHUD extends Control:
	var tutorial_reveal := 0
var failed := false
func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world := SurveyWorld.new()
	root.add_child(world)
	var actor := Node3D.new()
	world.add_child(actor)
	var layer := CanvasLayer.new()
	actor.add_child(layer)
	var hud := TutorialHUD.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	var arrival := preload("res://player/area_arrival.gd").new()
	hud.add_child(arrival)
	arrival.set_process(false)
	var plot: Dictionary = arrival.Layout.PLOTS["DistrictPolice"]
	actor.global_position = Vector3(plot.center.x, 0, plot.center.y)
	arrival._process(0.3)
	check(not arrival.visible and arrival.current_area.is_empty(), "Title appeared before compass reveal")
	hud.tutorial_reveal = 9
	arrival._process(0.3)
	check(arrival.visible and arrival.current_area == "DistrictPolice", "Compass reveal did not enable discovery")
	arrival.update_area(plot.center, 0.3)
	check(arrival.text == "Thana", "Thana arrival missing")
	await create_timer(0.4).timeout
	check(arrival.modulate.a > 0.99, "Fade in failed")
	await create_timer(1.6).timeout
	check(arrival.modulate.a < 0.01, "Title did not fade out")
	arrival.update_area(plot.center, 1.0)
	check(arrival.modulate.a < 0.01, "Repeated title while staying inside")
	check(arrival.area_at(plot.center + Vector2(plot.half.x + 18,0)) == "DistrictPolice", "Boundary hysteresis missing")
	arrival.update_area(Vector2.ZERO, 0.3)
	arrival.update_area(plot.center, 0.3)
	check(arrival.current_area == "DistrictPolice", "Reentry missing")
	arrival.update_area(arrival.Layout.PLOTS["Bhairavpur"].center, 0.3)
	arrival.update_area(arrival.Layout.PLOTS["BhairavpurEstate"].center, 0.3)
	check(arrival.current_area == "BhairavpurEstate", "Nested estate discovery missing")
	arrival.update_area(plot.center + Vector2(plot.half.x + 30,0), 0.1)
	check(arrival.current_area == "BhairavpurEstate", "Brief boundary change bypassed debounce")
	world.queue_free()
	await process_frame
	print("AREA ARRIVAL ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
