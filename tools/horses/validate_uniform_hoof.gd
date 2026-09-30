extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var horse: Node3D = load("res://horses/stable_horse.gd").new()
	var cart: Node3D = load("res://vehicles/horse_cart_candidate.gd").new()
	var carriage: Node3D = load("res://vehicles/family_carriage_candidate.gd").new()
	for node in [horse,cart,carriage]:
		scene.add_child(node)
		node.set_physics_process(false)
	var bridge := StaticBody3D.new()
	bridge.name = "TimberBridge"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10,.2,10)
	shape.shape = box
	bridge.position = Vector3(100,0,100)
	bridge.add_child(shape)
	scene.add_child(bridge)
	var results := []
	var failures := []
	for surface in ["earth","road","timber"]:
		var at := Vector3(600,.2,600) if surface=="earth" else (Vector3(-374,.2,230) if surface=="road" else Vector3(100,.2,100))
		for node in [horse,cart,carriage]: node.global_position = at
		for i in 3: await physics_frame
		assert(horse.ground_sound_surface()==surface,"surface diagnostic "+surface)
		for node in [horse,cart,carriage]:
			node.hoof_events = 0
			for i in 10:
				if node==horse: node._hoof_sound()
				elif node==cart: node._play_cart_hoof()
				else: node._play_carriage_hoof()
				var player: AudioStreamPlayer3D = node.hoof_players[i%node.hoof_players.size()]
				var expected = node.HoofRoadRecordedA if i%2==0 else node.HoofRoadRecordedB
				if player.stream!=expected or player.volume_db!=-8 or absf(player.pitch_scale-(1+(i%5-2)*.025))>.0001: failures.append(surface+" "+str(node.get_script().resource_path))
			results.append({"surface":surface,"script":node.get_script().resource_path,"events":10})
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","checks":results,"failures":failures}
	FileAccess.open("res://docs/world/uniform_hoof_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("UNIFORM HORSE HOOF ",report.status," | 90 stream/mix/pitch events")
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
