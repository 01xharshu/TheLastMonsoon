extends SceneTree
var issues: Array[String] = []
func check(value: bool, label: String) -> void:
	if not value: issues.append(label);push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(180).timeout.connect(func(): quit(2))
	var world := Node3D.new();world.name="RiverVillageValidation"
	root.add_child(world);current_scene=world
	var game_clock=preload("res://world/suryagarh/systems/game_time_system.gd").new();game_clock.name="GameTimeSystem";world.add_child(game_clock)
	world.add_child(load("res://world/suryagarh/generated/landscape.scn").instantiate())
	var charpai=load("res://objects/charpai.tscn").instantiate();charpai.name="Charpai";world.add_child(charpai)
	world.add_child(load("res://tools/world/river_village_fixture.gd").new())
	for frame in 8: await physics_frame
	var routines:=get_nodes_in_group("village_river_routine")
	check(routines.size()==1,"one live river group")
	if routines.is_empty():quit(1);return
	var routine = routines[0]
	routine.set_physics_process(false)
	var clock=world.get_node("GameTimeSystem");clock.clock_paused=true;clock.current_hour=6;clock.current_day=1
	check(routine.women.size()==3,"three independently rigged adult women")
	check(routine.SPEED>=1.0 and routine.SPEED<=1.4,"ordinary walking pace")
	check(not routine.has_node("RiverWashingLanding"),"no shared sitting or boarding platform at collection point")
	check(absf(routine.shore.z-235.0)>20.0,"collection clear of boat boarding route")
	check(absf(routine.journeys[0].path[5].z-routine.journeys[2].path[5].z)>1.5,"separate companion walking lanes")
	check(routine.shore.y<.06,"water access ramp ends at river level")
	var reached := {};var max_hand := 0.0;var max_ankle := 0.0;var worst := {}
	for step in 8000:
		routine.tick(.5)
		for woman in routine.women:
			woman.get_node("BodyCollider").force_update_transform()
			reached[woman.action]=true
			for error in woman.hand_errors.values():
				if error>max_hand: worst["hand"]={"stage":woman.action,"position":woman.global_position,"time":woman.elapsed};max_hand=error
			for error in woman.foot_errors.values():
				if error>max_ankle: worst["ankle"]={"stage":woman.action,"position":woman.global_position,"time":woman.elapsed,"slope":woman.travel_slope,"heading":woman.rotation.y,"direction":woman.travel_direction,"figure":woman.animation_player.get_node(woman.animation_player.root_node).position,"ankles":[woman.skeleton.to_global(woman.Contact.point(woman.skeleton,"foot_l")),woman.skeleton.to_global(woman.Contact.point(woman.skeleton,"foot_r"))]};max_ankle=error
		if step%1000==0: print("RIVER_ROUTE_PROGRESS ",step," ",routine.mode," ",routine.journeys[0].position)
		if step%100==0: await physics_frame
		if routine.mode=="visit" and routine.visit_seconds>17 and routine.visit_seconds<18:
			for woman in routine.women: check(woman.mouth_height<=.001,"pot mouth enters actual water")
		if step in [120,600,1200]:
			var state: Dictionary=routine.export_state()
			var save_helper=load("res://world/suryagarh/settlements/river_routine_save.gd")
			var collected: Dictionary=save_helper.collect(world)
			save_helper.restore(world,JSON.parse_string(JSON.stringify(collected)))
			check(routine.mode==state.mode and routine.journeys[0].position.distance_to(Vector3(state.members[0].position[0],state.members[0].position[1],state.members[0].position[2]))<.0001,"JSON save round trip "+str(step))
		if routine.blocked_frames>10:
			for i in routine.women.size(): print("BLOCKED ",i," ",routine.journeys[i].position," goal ",routine.journeys[i].goal)
			break
		if routine.mode=="home" and routine.completed_day==1: break
	check(max_hand<.015 and max_ankle<.015,"live wrist and ankle targets within 15mm")
	check(routine.completed_day==1,"physical journey returns and delivers")
	check(routine.blocked_frames==0,"route unobstructed by real world collision")
	for stage in ["depart","fill","wash","talk","pickup_pot","return","deliver","home"]:check(reached.has(stage),"stage visited "+stage)
	var before:Dictionary=routine.export_state()
	load("res://world/suryagarh/settlements/river_routine_save.gd").restore(world,{})
	check(routine.export_state()==before,"older saves leave routine defaults unchanged")
	routine.tick(1)
	check(routine.mode=="home","no duplicate departure same day")
	clock.current_day=2;clock.current_hour=5;routine.tick(1);check(routine.mode=="home","no predawn departure")
	clock.current_hour=6;routine.tick(.1);check(routine.mode=="depart","next morning restarts")
	var report:={"passed":issues.is_empty(),"issues":issues,"blocked_frames":routine.blocked_frames,"worst":worst,"max_hand_m":max_hand,"max_ankle_m":max_ankle,"shore":[routine.shore.x,routine.shore.y,routine.shore.z],"actions":reached.keys(),"in_world":true,"visual_approved":false}
	print("RIVER_WORLD ",JSON.stringify(report))
	world.queue_free();await process_frame;quit(0 if issues.is_empty() else 1)
