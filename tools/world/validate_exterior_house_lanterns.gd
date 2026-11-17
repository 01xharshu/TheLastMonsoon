extends SceneTree
## World-clock, fixture placement and paired native street views.
const NightLife = preload("res://world/suryagarh/settlements/village_night_life.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func set_clock(world: Node3D, minute: int) -> void:
	var clock: GameTimeSystem = world.get_node("GameTimeSystem")
	clock.total_game_minutes = minute
	clock._update_readable_time(true)
	world.get_node("Sun")._update_day_night_lighting()

func run() -> void:
	var saves: Node = root.get_node("SaveManager")
	saves.options.fullscreen = false
	saves.options.graphics_quality = 1
	saves.options.night_brightness = .5
	saves.apply_options()
	var world: Node3D = load(saves.WORLD).instantiate()
	root.add_child(world)
	current_scene = world
	var deadline := Time.get_ticks_msec() + 180000
	while world.get_node_or_null("Settlement/VillageNightLife") == null and Time.get_ticks_msec() < deadline:
		await process_frame
	for i in 20: await process_frame
	var lamps := get_nodes_in_group("village_exterior_lantern")
	check(lamps.size() == NightLife.EXTERIOR_HOMES.size(),"Only selected homes have an exterior lantern")
	check(get_nodes_in_group("village_oil_lamp").size() == 34,"Existing indoor lamps retained")
	if lamps.is_empty():
		await saves.quit_game(1)
		return
	var clock: GameTimeSystem = world.get_node("GameTimeSystem")
	clock.clock_paused = true
	for minute in [1079,1080,1380,359,360,540]:
		set_clock(world,minute)
		var lit: bool = minute >= 1080 or minute < 360
		for fixture in lamps:
			var pier: Node3D = fixture.get_parent().get_node("DoorPier")
			var light: OmniLight3D = fixture.get_node("ExteriorLight")
			var flame: Node3D = fixture.get_node("OilFlame")
			check(fixture.position.z > pier.position.z+.19,"Wick is outside the wall")
			check(light.position.is_equal_approx(flame.position),"Light originates at the wick")
			check(light.visible == lit and flame.visible == lit and fixture.visible,"Clock toggles light and flame while keeping the housing")
			check(light.shadow_enabled and light.distance_fade_enabled and light.distance_fade_shadow < light.distance_fade_begin,"Near shadows and bounded render range")
	var out := OS.get_environment("TLM_EXTERIOR_LANTERN_REVIEW")
	if out.is_empty(): out = OS.get_environment("TLM_TUTORIAL_OUTPUT")
	if not out.is_empty() and DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		camera.fov = 63
		world.add_child(camera)
		var player: Node3D = world.get_node("Player")
		player.set_physics_process(false)
		player.get_node("UI").hide()
		camera.make_current()
		var facade: Node3D = lamps[0]
		var at := Vector2(-376.8,171.0)
		var eye := Vector3(at.x,world.layout.height(at.x,at.y)+1.65,at.y)
		for phase in [["night",1320],["morning",540]]:
			set_clock(world,phase[1])
			player.global_position = eye + Vector3(0,0,-8)
			camera.global_position = eye
			camera.look_at(facade.global_position.lerp(Vector3(-371,eye.y,189),.28))
			for i in 10: await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(out.path_join(phase[0]+".png")) == OK,"Captured paired "+phase[0]+" view")
	print("EXTERIOR HOUSE LANTERNS ", "PASS" if failures == 0 else "FAIL", " | ", lamps.size(), " fixtures, six clock samples")
	await saves.quit_game(0 if failures == 0 else 1)
