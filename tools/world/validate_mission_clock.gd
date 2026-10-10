extends SceneTree

const Clock = preload("res://world/suryagarh/systems/game_time_system.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _initialize() -> void:
	var clock = Clock.new()
	clock._ready()
	var start: float = clock.total_game_minutes
	for i in 36000:
		clock._process(1.0 / 60.0)
	check(absf(clock.total_game_minutes - start - 1440.0) < 0.000001, "Normal day must take 600 seconds")
	check(clock.current_day == 2 and clock.current_hour == 6 and clock.current_minute == 0, "Normal day rollover")
	clock.set_mission_clock_slowed(&"mission_a", true)
	clock.set_mission_clock_slowed(&"mission_a", true)
	start = clock.total_game_minutes
	clock._process(600.0)
	check(absf(clock.total_game_minutes - start - 480.0) < 0.000001, "Slow mission: 600 seconds = 8 hours")
	clock._process(1200.0)
	check(absf(clock.total_game_minutes - start - 1440.0) < 0.000001, "Slow mission day must take 1800 seconds")
	clock.set_mission_clock_slowed(&"mission_b", true)
	clock.set_mission_clock_slowed(&"mission_a", false)
	check(is_equal_approx(clock.get_clock_multiplier(), 1.0 / 3.0), "Overlapping mission release must preserve slowdown")
	start = clock.total_game_minutes
	clock.clock_paused = true
	clock._process(600.0)
	check(clock.total_game_minutes == start, "Pause must stop slow clock")
	clock.advance_hours(8.0)
	check(is_equal_approx(clock.total_game_minutes - start, 480.0), "Explicit skips must remain exact")
	clock.clock_paused = false
	clock.set_mission_clock_slowed(&"mission_b", false)
	check(clock.get_clock_multiplier() == 1.0, "Final mission exit restores normal speed")
	clock.set_mission_clock_slowed(&"", true)
	check(clock.get_clock_multiplier() == 1.0, "Empty mission identifier must be ignored")
	clock.set_mission_clock_slowed(&"mission_a", true)
	clock.clear_mission_clock_slowdowns()
	check(clock.get_clock_multiplier() == 1.0, "Reset clears mission owners")
	# Exercise actual story entry/restore synchronization without loading the world.
	var world := Node.new()
	clock.name = "GameTimeSystem"
	world.add_child(clock)
	var story = load("res://story/dev_story.gd").new()
	world.add_child(story)
	var player := CharacterBody3D.new()
	story.player = player
	story.state = "farm"
	player.set_meta("farm_lesson_started", false)
	story.sync_training_clock()
	check(clock.get_clock_multiplier() == 1.0, "Travel to farm stays normal")
	player.set_meta("farm_lesson_started", true)
	story.sync_training_clock()
	check(is_equal_approx(clock.get_clock_multiplier(), 1.0 / 3.0), "Started/restored Chacha training slows clock")
	story.state = "complete"
	story.sync_training_clock()
	check(clock.get_clock_multiplier() == 1.0, "Completed Chacha training restores clock")
	story.state = "farm"
	story.sync_training_clock()
	story._exit_tree()
	check(clock.get_clock_multiplier() == 1.0, "Story teardown releases slowdown")
	player.free()
	world.free()
	for failure in failures:
		push_error(failure)
	print("MISSION CLOCK: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
