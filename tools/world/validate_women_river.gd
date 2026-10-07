extends SceneTree
var issues: Array[String] = []
func check(value: bool, label: String) -> void:
	if not value: issues.append(label);push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(180).timeout.connect(func(): quit(2))
	var world: Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world);current_scene=world
	for frame in 8: await physics_frame
	var routines:=get_nodes_in_group("village_river_routine")
	check(routines.size()==1,"one live river group")
	if routines.is_empty():quit(1);return
	var routine = routines[0]
	routine.set_physics_process(false)
	var clock=world.get_node("GameTimeSystem");clock.clock_paused=true;clock.current_hour=6;clock.current_day=1
	var player=world.get_node("Player");player.set_physics_process(false);player.global_position=Vector3(-410,10,320)
	check(routine.women.size()==3,"three independently rigged adult women")
	check(routine.shore.y<.06,"water access ramp ends at river level")
	var reached := {};var samples := []
	for step in 8000:
		routine.tick(.5)
		for woman in routine.women:
			woman.get_node("BodyCollider").force_update_transform()
			reached[woman.action]=true
		if step%1000==0: print("RIVER_ROUTE_PROGRESS ",step," ",routine.mode," ",routine.journeys[0].position)
		if step%100==0: await physics_frame
		if routine.mode=="visit" and routine.visit_seconds>17 and routine.visit_seconds<18:
			for woman in routine.women: check(woman.mouth_height<=.001,"pot mouth enters actual water")
		if step in [120,600,1200]:
			var state: Dictionary=routine.export_state()
			routine.restore_state(JSON.parse_string(JSON.stringify(state)))
			check(routine.export_state()==state,"JSON save round trip "+str(step))
		if routine.blocked_frames>10:
			for i in routine.women.size(): print("BLOCKED ",i," ",routine.journeys[i])
			break
		if routine.mode=="home" and routine.completed_day==1: break
	check(routine.completed_day==1,"physical journey returns and delivers")
	check(routine.blocked_frames==0,"route unobstructed by real world collision")
	for stage in ["depart","fill","wash","talk","pickup_pot","return","deliver","home"]:check(reached.has(stage),"stage visited "+stage)
	var before:Dictionary=routine.export_state();routine.tick(1)
	check(routine.mode=="home","no duplicate departure same day")
	clock.current_day=2;clock.current_hour=5;routine.tick(1);check(routine.mode=="home","no predawn departure")
	clock.current_hour=6;routine.tick(.1);check(routine.mode=="depart","next morning restarts")
	var report:={"passed":issues.is_empty(),"issues":issues,"blocked_frames":routine.blocked_frames,"shore":[routine.shore.x,routine.shore.y,routine.shore.z],"actions":reached.keys(),"in_world":true,"visual_approved":false}
	FileAccess.open("res://docs/characters/npcs/river_world_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("RIVER_WORLD ",JSON.stringify(report))
	world.queue_free();await process_frame;quit(0 if issues.is_empty() else 1)
