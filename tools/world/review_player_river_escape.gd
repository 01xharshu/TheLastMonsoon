extends SceneTree
## Normal-speed local river review using production player, mounts and water.
const Layout = preload('res://world/suryagarh/landscape_layout.gd')
const Horse = preload('res://horses/stable_horse.gd')
const OpenCart = preload('res://vehicles/horse_cart_candidate.gd')
const Carriage = preload('res://vehicles/family_carriage_candidate.gd')
class ReviewWorld extends Node3D:
	var layout := Layout.new()
	var player: CharacterBody3D
	func _physics_process(_delta: float) -> void:
		if player == null: return
		var p := player.global_position
		var deep := layout.height(p.x,p.z) < Layout.WATER_LEVEL-1.0
		player.set_water_state(deep and p.y < Layout.WATER_LEVEL+(0.65 if player.is_swimming else 0.3),Layout.WATER_LEVEL)
		player.set_meta('river_current',preload('res://world/suryagarh/river_dynamics.gd').current_at(p) if deep else Vector3.ZERO)
var output := ''
var selected_case := ''
var save_captures := true
func _initialize() -> void: run.call_deferred()
func capture(label: String) -> void:
	if DisplayServer.get_name() == 'headless' or not save_captures: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+'/'+label+'.png')
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with('--output='): output = arg.trim_prefix('--output=')
		if arg.begins_with('--case='): selected_case = arg.trim_prefix('--case=')
		if arg=='--no-captures': save_captures = false
	if output.is_empty(): quit(2); return
	root.get_node('SaveManager').settings_path = output+'/settings.cfg'
	root.get_node('SaveManager').save_root = output+'/saves'
	root.get_node('SaveManager').options.fullscreen = false
	root.get_node('SaveManager').options.graphics_quality = 1
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size = Vector2i(1280,720)
	var world := ReviewWorld.new(); root.add_child(world); current_scene = world
	var clock := preload('res://world/suryagarh/systems/game_time_system.gd').new()
	clock.name = 'GameTimeSystem'; world.add_child(clock); clock.set_process(false)
	var env := WorldEnvironment.new(); var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky := Sky.new(); sky.sky_material = ProceduralSkyMaterial.new(); settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(.65,.72,.78); settings.ambient_light_energy = .55
	env.environment = settings; world.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40,-25,0)
	sun.shadow_enabled = true; world.add_child(sun)
	var river := preload('res://world/suryagarh/river_dynamics.gd').new(); river.name = 'RiverDynamics'; world.add_child(river)
	var actor: CharacterBody3D = load('res://player/player.tscn').instantiate()
	actor.position = Vector3(world.layout.river_x(165),1,165); world.add_child(actor); world.player = actor
	actor.get_node('PlayerSafety').checkpoint_elapsed = -1000.0
	var bag: Node = actor.get_node('VisualRoot/EquipmentVisuals/WaterBagVisual')
	print('POUCH SOURCE PREP ',JSON.stringify({'readbacks':bag.source_readbacks,'cache_hits':bag.source_cache_hits,'microseconds':bag.source_prepare_usec}))
	actor.get_node('UI').hide(); actor.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var camera := Camera3D.new(); camera.fov = 55; camera.far = 1200; world.add_child(camera); camera.current = true
	root.get_node("SaveManager")._apply_render_budget(root,1)
	var caption_layer := CanvasLayer.new(); root.add_child(caption_layer)
	var caption := Label.new(); caption.position = Vector2(24,20); caption.add_theme_font_size_override('font_size',24); caption_layer.add_child(caption)
	var failed := false
	for item in [['horse',''],['open_cart','DriverSeat'],['carriage_right','RearPassengerRight'],['carriage_left','RearPassengerLeft']]:
		if not selected_case.is_empty() and item[0] != selected_case: continue
		actor.set_physics_process(false); actor.health = 100; actor.is_swimming = false
		actor.remove_meta('river_escape_remaining')
		var mounted: Node
		var vehicle: Node3D
		if item[0]=='horse':
			vehicle = Horse.new(); world.add_child(vehicle); mounted = vehicle
		else:
			vehicle = OpenCart.new() if item[0]=="open_cart" else Carriage.new()
			if item[0]!='open_cart': vehicle.add_to_group('household_coach')
			world.add_child(vehicle); mounted = vehicle.boarding
		vehicle.set_physics_process(false); mounted.set_physics_process(false)
		vehicle.global_position = Vector3(world.layout.river_x(165),1.0,165)
		actor.global_position = vehicle.global_position+Vector3.UP*2.0
		mounted.rider = actor; mounted.saved_layer = actor.collision_layer; mounted.saved_mask = actor.collision_mask
		actor.collision_layer = 0; actor.collision_mask = 0
		actor.set_meta('mounted_vehicle',mounted)
		if item[0]!='horse':
			mounted.seat_name = item[1]; mounted.role = 'driver' if item[0]=='open_cart' else 'passenger'
			actor.set_meta('cart_role',mounted.role)
			mounted._sync_rider()
		actor.get_node('PlayerSafety').set_physics_process(false)
		caption.text = item[0].replace('_',' ').capitalize()+' · river escape'
		camera.global_position = vehicle.global_position+Vector3(7,3.5,8)
		camera.look_at(vehicle.global_position+Vector3.UP)
		await create_timer(.8).timeout
		actor.set_physics_process(true)
		actor.get_node('PlayerSafety').set_physics_process(true)
		vehicle.set_physics_process(true); mounted.set_physics_process(true)
		var deadline := Time.get_ticks_msec()+6000
		while actor.has_meta('mounted_vehicle') and Time.get_ticks_msec()<deadline: await process_frame
		if actor.has_meta('mounted_vehicle'):
			print('FAIL '+item[0]+' did not release'); failed=true
		else:
			var save_blocked: bool = not root.get_node('SaveManager').save_game(world,4)
			print(('PASS ' if save_blocked else 'FAIL ')+item[0]+' cannot checkpoint mid escape')
			if not save_blocked: failed=true
			var started := Time.get_ticks_msec()
			var started_frame := Engine.get_physics_frames()
			for seconds in [.08,.24,.5,1.1,2.5]:
				while Engine.get_physics_frames()-started_frame < int(seconds*60.0) and Time.get_ticks_msec()-started<20000:
					camera.look_at(vehicle.global_position.lerp(actor.global_position,0.65)+Vector3.UP*.6)
					await process_frame
				await capture(item[0]+'_'+str(int(seconds*1000)))
			print(item[0]+' simulation_seconds='+str(float(Engine.get_physics_frames()-started_frame)/Engine.physics_ticks_per_second)+', wall_ms='+str(Time.get_ticks_msec()-started))
			print(('PASS ' if actor.health>0 and actor.is_swimming else 'FAIL ')+item[0]+' live jump/swim, health='+str(actor.health))
			if actor.health<=0 or not actor.is_swimming: failed=true
		vehicle.queue_free(); await process_frame
	print('RIVER MOTION REVIEW '+('FAIL' if failed else 'PASS'))
	preload('res://tools/test_audio_cleanup.gd').finish(self,1 if failed else 0)
