extends "res://tools/world/validate_crime_perception.gd"
## Reproduce station standing contact before invoking an arrest controller.
func run()->void:
	var world:=Node3D.new();root.add_child(world);current_scene=world
	var clock:=GameTimeSystem.new();clock.name="GameTimeSystem";world.add_child(clock)
	var building:Node3D=load("res://world/suryagarh/settlements/civic_building.gd").new();building.police=true;world.add_child(building)
	var actor:CharacterBody3D=load("res://player/player.tscn").instantiate();world.add_child(actor)
	actor.global_position=building.to_global(Vector3(9.5,.901,9))
	var previous:=actor.global_position
	var max_step:=0.0
	for frame in 90:
		await physics_frame
		var at:=actor.global_position
		max_step=maxf(max_step,at.distance_to(previous))
		if at.distance_to(previous)>.16:print("STATION CONTACT STEP ",building.to_local(previous)," -> ",building.to_local(at)," velocity ",actor.velocity)
		previous=at
	check(max_step<.16,"standing at station does not produce a large movement step")
	print("STATION CONTACT ",JSON.stringify({"maximum_step":max_step,"position":str(building.to_local(actor.global_position)),"status":"PASS" if failures.is_empty() else "FAIL"}))
	world.queue_free();await sync()
	root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
