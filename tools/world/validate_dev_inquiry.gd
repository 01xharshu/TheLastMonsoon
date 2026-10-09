extends SceneTree
class FixtureWorld:
	extends Node3D
	var layout=preload("res://world/suryagarh/landscape_layout.gd").new()
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	if not value:failures.append(label);push_error(label)
func settle(player: CharacterBody3D,at: Vector3) -> void:
	player.global_position=at;player.velocity=Vector3.ZERO
	for frame in 15:await physics_frame
func run() -> void:
	var world:=FixtureWorld.new();root.add_child(world)
	var clock=preload("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
	var player: CharacterBody3D=load("res://player/player.tscn").instantiate();player.name="Player";world.add_child(player)
	var station=load("res://world/suryagarh/settlements/civic_building.gd").new();station.name="DistrictPolice";station.police=true;world.add_child(station)
	var inquiry=load("res://story/dev_inquiry.gd").new();world.add_child(inquiry)
	for frame in 30:await physics_frame
	check(inquiry.configured and inquiry.stage=="dormant","story waits for morning handoff")
	check(inquiry.guards.size()==4 and inquiry.officials.size()==3,"multiple guards and three chamber officials")
	for guard in inquiry.guards:check(guard.rifle!=null and guard.rifle.visible,"guard visibly armed")
	check(inquiry.expressions[0].entries.size()>0,"official facial expressions available")
	for expression in inquiry.expressions:
		for entry in expression.entries:
			check(entry.node.mesh.get_surface_count()==entry.source.get_surface_count(),"expression retains body surfaces")
			for surface in entry.source.get_surface_count():
				var before: Array=entry.source.surface_get_arrays(surface)
				var after: Array=entry.node.mesh.surface_get_arrays(surface)
				check(before[Mesh.ARRAY_VERTEX]==after[Mesh.ARRAY_VERTEX] and before[Mesh.ARRAY_INDEX]==after[Mesh.ARRAY_INDEX] and before[Mesh.ARRAY_WEIGHTS]==after[Mesh.ARRAY_WEIGHTS],"expression retains body topology and skin")
	inquiry.begin();check(inquiry.stage=="police","morning starts police objective")
	check(inquiry.destination.global_position==inquiry.police_prompt.global_position,"marker follows actual inquiry point")
	check(not inquiry.can_request("superior"),"superior cannot precede initial inquiry")
	await settle(player,inquiry.police_prompt.global_position+Vector3(0,0,1))
	check(inquiry.request("police",player),"police inquiry starts")
	check(not player.is_physics_processing(),"dialogue contains movement")
	check(inquiry.player_expression!=null and inquiry.player_expression.entries.size()>0,"Arjun expression reuses full body")
	inquiry._process(30)
	check(inquiry.stage=="superior" and player.is_physics_processing(),"refusal unlocks superior objective and control")
	var state: Dictionary=inquiry.export_state();inquiry.restore_state(state)
	check(inquiry.stage=="superior","inquiry stage restoration")
	await settle(player,inquiry.office_prompt.global_position+Vector3(0,0,.25))
	check(inquiry.request("superior",player),"chamber meeting starts")
	inquiry._process(11)
	check(inquiry.line_index==2 and inquiry.officials[1].speaking,"first official mocks Dev")
	inquiry._process(10)
	check(inquiry.line_index==4 and inquiry.officials[0].speaking,"superior joins humiliation")
	inquiry._process(5.5)
	check(inquiry.line_index==5 and inquiry.subtitle.text.begins_with("Arjun:"),"Arjun calls out humiliation")
	inquiry._process(6)
	check("Soldiers!" in inquiry.subtitle.text,"official explicitly summons soldiers")
	inquiry._process(6)
	check(inquiry.stage=="summoning" and inquiry.guard_paths.size()==2,"two corridor soldiers receive routes")
	print("SOLDIER ROUTE POINTS ",inquiry.guard_paths[0].size()," / ",inquiry.guard_paths[1].size())
	for frame in 1900:
		await physics_frame
		if inquiry.stage!="summoning":break
	check(inquiry.stage=="punishment","both soldiers enter and punishment starts")
	check(player.get_meta("detention_action","")!="","existing detention receives player")
	check(inquiry.coordinator.reason=="story_order","story punishment is distinct from witnessed crime")
	print("SOLDIER POSITIONS ",station.to_local(inquiry.guards[2].global_position)," / ",station.to_local(inquiry.guards[3].global_position))
	for frame in 1200:
		await physics_frame
		if inquiry.stage=="released":break
	check(inquiry.stage=="released" and player.get_meta("detention_action","")=="","custody releases and completes story beat")
	check(player.is_physics_processing() and not player.get_meta("document_busy",false),"punishment restores movement and interaction")
	var manager: Node=root.get_node("SaveManager")
	var temporary:=OS.get_environment("TLM_INQUIRY_SAVE_DIR")
	if not temporary.is_empty():
		manager.save_root=temporary
		# Finish the guard's return before normal saving is allowed.
		for frame in 1200:
			await physics_frame
			if inquiry.coordinator.phase=="idle":break
		check(manager.save_game(world,1),"isolated story save")
		inquiry.stage="dormant";manager.pending_slot=1;manager.apply_pending(world)
		check(inquiry.stage=="released","save restores inquiry progress without replaying punishment")
	print("DEV INQUIRY: "+("PASS" if failures.is_empty() else "FAIL "+str(failures)))
	world.queue_free();await process_frame;call_deferred("finish",0 if failures.is_empty() else 1)
func finish(status: int) -> void:preload("res://tools/test_audio_cleanup.gd").finish(self,status)
