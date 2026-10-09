extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var clock := preload("res://world/suryagarh/systems/game_time_system.gd").new()
	clock.name = "GameTimeSystem"
	clock.starting_hour = 12
	world.add_child(clock)
	clock.set_process(false)
	var flock := preload("res://world/suryagarh/sky_birds.gd").new()
	world.add_child(flock)
	assert(flock.birds.size() == 60)
	var start: Vector3 = flock.birds[0].position
	flock._process(1.0)
	assert(flock.birds[0].position.distance_to(start) > 4.0)
	assert(flock.wings.size() == 120)
	var forward: Vector3 = -flock.birds[0].basis.z
	var before: Vector3 = flock.birds[0].position
	flock._process(0.05)
	var displacement: Vector3 = flock.birds[0].position - before
	displacement.y = 0.0
	assert(forward.dot(displacement.normalized()) > 0.98)
	assert(is_equal_approx(flock.wings[0].rotation.z, -flock.wings[1].rotation.z))
	for bird in flock.birds:
		assert(bird.position.y > flock.layout.height(bird.position.x, bird.position.z) + 15.0)
	# Sweep complete routes at intermediate positions to catch clearance regressions.
	var baseline: float = flock.elapsed
	var update_start := Time.get_ticks_usec()
	for sample_index in range(240):
		flock.elapsed = sample_index * 0.5
		flock._update_birds()
		for bird in flock.birds:
			assert(bird.position.y > flock.layout.height(bird.position.x, bird.position.z) + 15.0)
		for anchor in [Vector3(-230,0,180), Vector3(12,0,155), Vector3(-440,0,-200)]:
			var nearest_distance := INF
			for bird in flock.birds:
				nearest_distance = minf(nearest_distance, Vector2(bird.position.x-anchor.x,bird.position.z-anchor.z).length())
			assert(nearest_distance < 180.0)
	print("SKY flight/clearance sweep us per update+validation=", (Time.get_ticks_usec()-update_start)/240.0)
	var motion_start := Time.get_ticks_usec()
	for iteration in range(1000): flock._update_birds()
	print("SKY motion-only us per update=", (Time.get_ticks_usec()-motion_start)/1000.0)
	flock.elapsed = baseline
	for hour in range(24):
		clock.total_game_minutes = hour * 60.0
		flock._process(0.1)
		if hour >= 7 and hour <= 17: assert(flock.visible)
		if hour <= 5 or hour >= 19: assert(not flock.visible)
	clock.total_game_minutes = 23.0 * 60.0
	flock._process(0.1)
	var stopped := flock.elapsed
	flock._process(10.0)
	assert(flock.elapsed == stopped)
	clock.total_game_minutes = 6.0 * 60.0
	flock._process(0.1)
	assert(flock.activity > 0.0 and flock.activity < 1.0)
	clock.total_game_minutes = 9.0 * 60.0
	flock._process(0.1)
	assert(flock.visible and flock.activity == 1.0)
	print("SKY BIRDS PASS: flight/clearance, 24h schedule, twilight fade, night idle, time-jump recovery")
	world.queue_free()
	await process_frame
	preload("res://tools/test_audio_cleanup.gd").stop(root)
	await preload("res://tools/test_audio_cleanup.gd").settle(self)
	quit()
