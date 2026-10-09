extends SceneTree
## The opening/story guide reuses the real field-map waypoint and respects choice.
class Inquiry extends Node3D:
	var configured := true
	var stage := "police"
	var destination: Node3D

var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var clock := GameTimeSystem.new()
	clock.name = "GameTimeSystem"
	world.add_child(clock)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	actor.name = "Player"
	world.add_child(actor)
	actor.set_physics_process(false)
	var inquiry := Inquiry.new()
	inquiry.name = "DevInquiry"
	world.add_child(inquiry)
	inquiry.destination = Node3D.new()
	inquiry.add_child(inquiry.destination)
	inquiry.destination.position = Vector3(30,0,50)
	inquiry.destination.set_meta("parking_label","Find Dev · Police inquiry")
	var map: Control = actor.get_node("UI/WorldMap")
	actor.set_meta("opening_active",true)
	for frame in 4: await process_frame
	check(not map.waypoint.is_finite(),"Marker appeared during opening")
	actor.remove_meta("opening_active")
	map.follow_story_destination()
	for frame in 4: await process_frame
	check(map.waypoint == Vector2(30,50) and map.marker.visible,"Opening did not activate existing world marker")
	inquiry.stage = "superior"
	inquiry.destination.position = Vector3(40,0,60)
	inquiry.destination.set_meta("parking_label","Find Dev · Superior’s chamber")
	for frame in 4: await process_frame
	check(map.waypoint == Vector2(40,60),"Story referral did not update waypoint")
	map.select_point(map.map_rect.get_center())
	map.waypoint = Vector2(80,90)
	inquiry.destination.position = Vector3(60,0,70)
	for frame in 4: await process_frame
	check(map.waypoint == Vector2(80,90),"Story overwrote player-selected waypoint")
	map.follow_story = true
	map.story_site = ""
	map.selected_site = ""
	for frame in 4: await process_frame
	check(map.waypoint == Vector2(80,90) and not map.follow_story,"Loaded custom waypoint overwritten")
	map.follow_story_destination()
	inquiry.destination.set_meta("parking_label","")
	for frame in 4: await process_frame
	check(not map.waypoint.is_finite(),"Finished story guide leaves stale waypoint")
	print("STORY WAYPOINT: ","FAIL" if failed else "PASS"," | opening containment, world marker, referral, manual/loaded choice, stale guide cleanup")
	preload("res://tools/test_audio_cleanup.gd").finish(self,1 if failed else 0)
