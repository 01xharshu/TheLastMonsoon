extends SceneTree
## Actual house/rig/timeline in an isolated render, without district GPU load.
class ReviewWorld extends Node3D:
	var player: CharacterBody3D
	var player_camera: Camera3D

var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func run() -> void:
	var saves := root.get_node("SaveManager")
	saves.options.fullscreen = false
	saves.options.vsync = false
	saves.options.graphics_quality = 0
	saves.apply_options()
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.always_on_top = true
	root.grab_focus()
	var world := ReviewWorld.new()
	root.add_child(world)
	current_scene = world
	var clock := GameTimeSystem.new()
	clock.name = "GameTimeSystem"
	world.add_child(clock)
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.65,.72,.78)
	env.ambient_light_energy = .55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env_node.environment = env
	world.add_child(env_node)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	world.add_child(moon)
	var sun: DirectionalLight3D = load("res://world/suryagarh/systems/sun_controller.gd").new()
	sun.name = "Sun"
	sun.daytime_sun_energy = 1.5
	sun.sun_azimuth_degrees = -55
	world.add_child(sun)
	var bed: Node3D = load("res://objects/charpai.tscn").instantiate()
	bed.name = "Charpai"
	world.add_child(bed)
	var builder: Node3D = load("res://tools/world/opening_house_builder.gd").new()
	world.add_child(builder)
	var home: Node3D = builder.make_building("BhairavpurHouse0",Vector2(-343,214),Vector2(9.5,7.2),false,false,false,true)
	home.rotation.y = PI
	var detail = load("res://world/suryagarh/settlements/bhairavpur_house_detail.gd").new()
	var palette: Array[Material] = [builder.ochre]
	detail.configure(builder,palette)
	detail.house(home,Vector2(9.5,7.2),0)
	load("res://world/suryagarh/settlements/arjun_house.gd").new().furnish(builder,home)
	world.player = load("res://player/player.tscn").instantiate()
	world.player.name = "Player"
	world.add_child(world.player)
	world.player_camera = world.player.get_node("CameraPivot/SpringArm3D/Camera3D")
	world.player.set_physics_process(false)
	world.player.global_position = home.to_global(Vector3(-2.6,1.14,1.27))
	for frame in 10: await process_frame
	var audio := root.get_node("WorldAudio")
	var wind := root.get_node("WindSystem")
	world.player.set_physics_process(true)
	audio.set_opening_quiet(true)
	await create_timer(.15).timeout
	var recorder := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0,recorder)
	recorder.set_recording_active(true)
	var record_started := Time.get_ticks_msec()
	var opening = load("res://story/opening_sequence.gd").new()
	opening.name = "OpeningSequence"
	world.add_child(opening)
	opening.start(world)
	opening.set_process_input(false)
	check(opening.lamp.scale.is_equal_approx(Vector3.ONE*.35),"Diya size was not integrated")
	check(opening.lamp.get_child_count() == 9,"Lantern case geometry remains")
	check(opening.sound.players.size() == 6,"Night/morning synthetic ambience remains")
	check(world.player.get_node("VisualRoot/CharacterVisual").model.get_meta("opening_clothing_fitted",0) >= 4,"Complete body/clothes fit missing")
	if OS.get_environment("TLM_OPENING_MORNING_ONLY") == "1": opening.morning()
	var at: Vector3 = opening.lamp.position
	var photographed := {}
	while opening.state == "night":
		await process_frame
		if opening.state != "night": break
		check(opening.lamp.position.is_equal_approx(at),"Diya lifts during lighting")
		check(audio.is_opening_quiet(),"World audio not suppressed at night")
		check(not wind.ambience.playing,"Wind leaked into night opening")
		for voice in audio.voices: check(not voice.playing,"NPC/world audio leaked into night opening")
		var beat := int(opening.elapsed)
		if beat in [3,6,8,16] and not photographed.has(beat):
			photographed[beat] = true
			var out := OS.get_environment("TLM_OPENING_TEST_OUTPUT")
			if out != "" and DisplayServer.get_name() != "headless":
				RenderingServer.force_draw()
				root.get_texture().get_image().save_png(out+"/opening_%02d.png" % beat)
	var morning_offset := float(Time.get_ticks_msec()-record_started)/1000.0
	check(clock.current_hour == 6 and clock.current_day == 2,"Morning clock failed")
	check(world.get_node("WorldEnvironment").environment.ambient_light_energy >= .3,"Morning remains dark")
	check(world.get_node("Sun").light_energy > .05,"Morning sun remains disabled")
	check(not audio.is_opening_quiet(),"Morning ambience remains muted")
	var birds_before: int = audio.event_counts.get("sparrow",0)
	var previous_gain: float = audio.ambience_gain
	var morning_shot := false
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec()-started < 12000:
		await process_frame
		check(audio.ambience_gain >= previous_gain,"Morning audio fade reversed")
		previous_gain = audio.ambience_gain
		if not morning_shot and Time.get_ticks_msec()-started > 1800:
			morning_shot = true
			var shot_folder := OS.get_environment("TLM_OPENING_TEST_OUTPUT")
			if shot_folder != "" and DisplayServer.get_name() != "headless":
				RenderingServer.force_draw()
				root.get_texture().get_image().save_png(shot_folder+"/opening_morning.png")
	var out_morning := OS.get_environment("TLM_OPENING_TEST_OUTPUT")
	if out_morning != "" and DisplayServer.get_name() != "headless":
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(out_morning+"/opening_morning.png")
	check(audio.ambience_gain == 1.0,"Morning fade did not finish")
	check(audio.event_counts.get("sparrow",0) > birds_before,"Morning bird chirp missing")
	check(wind.ambience.playing,"Morning wind did not resume")
	var press := InputEventKey.new()
	press.keycode = KEY_W
	press.pressed = true
	opening._input(press)
	await create_timer(1.8).timeout
	check(opening.state == "done","Player release failed")
	check(wind.ambience.playing,"Ambience cut off at control release")
	check(world.player.is_physics_processing(),"Player controls not restored")
	recorder.set_recording_active(false)
	var recording := recorder.get_recording()
	if DisplayServer.get_name() != "headless":
		check(recording != null and recording.data.size() > 100000,"Native audio recording empty")
		var out := OS.get_environment("TLM_OPENING_TEST_OUTPUT")
		if recording != null and out != "":
			recording.save_to_wav(out+"/opening_mix.wav")
			var timing := FileAccess.open(out+"/timing.json",FileAccess.WRITE)
			timing.store_string(JSON.stringify({"morning":morning_offset}))
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	# Skip also restores dawn audio, with no repeated clock advance.
	world.player.set_physics_process(false)
	var skip = load("res://story/opening_sequence.gd").new()
	world.add_child(skip)
	skip.start(world)
	skip.set_process_input(false)
	press.keycode = KEY_ESCAPE
	skip._input(press)
	var minutes: float = clock.total_game_minutes
	skip.morning()
	check(clock.total_game_minutes == minutes,"Repeated morning advanced twice")
	check(not audio.is_opening_quiet(),"Skip leaves audio suppressed")
	skip._release()
	preload("res://tools/test_audio_cleanup.gd").stop(root)
	await preload("res://tools/test_audio_cleanup.gd").settle(self)
	print("OPENING INTEGRATION: ","FAIL" if failed else "PASS"," | stationary small diya, case removed, quiet night, gradual morning/birds, control/skip handoff; final acting/listening separate")
	quit(1 if failed else 0)
