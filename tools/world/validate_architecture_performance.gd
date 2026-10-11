extends SceneTree
## Same-scene interaction broad-phase attribution; not whole-game FPS acceptance.
func _initialize() -> void:run.call_deferred()
func median(values: Array[float]) -> float:
	values.sort();return values[values.size()/2]
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Requires native renderer");quit(2);return
	var saves:=root.get_node("SaveManager")
	saves.options.graphics_quality=1;saves.options.vsync=false;saves.options.fullscreen=false;saves.apply_options()
	var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	var actor:CharacterBody3D=world.get_node("Player")
	actor.set_script(load("res://tools/world/runtime_interaction_reference.gd"))
	root.add_child(world);current_scene=world
	for frame in 60:await process_frame
	world.process_mode=Node.PROCESS_MODE_DISABLED
	var failures:Array[String]=[]
	var camera:Camera3D=actor.get_node("CameraPivot/SpringArm3D/Camera3D")
	for spec in [["village",Vector2(-310,230)],["market",Vector2(-295,-310)],["cantonment",Vector2(640,470)]]:
		var at:Vector2=spec[1]
		actor.global_position=Vector3(at.x,world.layout.height(at.x,at.y)+.95,at.y)
		actor.rotation=Vector3.ZERO;actor.visual_root.rotation=Vector3.ZERO
		camera.global_position=actor.global_position+Vector3(0,1.4,-2);camera.look_at(actor.global_position+Vector3(0,1.0,3));camera.make_current()
		actor.use_spatial_index=true
		actor.nearby_interactables(13)
		for frame in 10:await process_frame
		var parity:=true
		var indexed:Array[float]=[];var global_scan:Array[float]=[]
		for round in 7:
			for mode in ([false,true] if round%2==0 else [true,false]):
				actor.use_spatial_index=mode
				var selected:Interactable=actor._find_interactable()
				actor.use_spatial_index=not mode
				if actor._find_interactable()!=selected:parity=false
				actor.use_spatial_index=mode
				var started:=Time.get_ticks_usec()
				for i in 200:actor._find_interactable()
				var cost:float=Time.get_ticks_usec()-started
				if mode:indexed.append(cost)
				else:global_scan.append(cost)
		var wall:Array[float]=[]
		for frame in 60:
			var started:=Time.get_ticks_usec();await process_frame;wall.append((Time.get_ticks_usec()-started)/1000.0)
		if not parity:failures.append(str(spec[0]))
		var candidates:Array[Node]=actor.nearby_interactables(13)
		print("ARCHITECTURE ",JSON.stringify({"region":spec[0],"selection_parity":parity,"global_200_calls_us":median(global_scan),"indexed_200_calls_us":median(indexed),"global_interactables":get_nodes_in_group("interactables").size(),"broad_phase_candidates":candidates.size(),"viewport":str(root.size),"scale_3d":root.scaling_3d_scale,"physical_3d_pixels":str(Vector2(root.size)*root.scaling_3d_scale),"frozen_frame_median_ms":median(wall),"scope":"frozen actual-world query attribution, not gameplay FPS"}))
	world.process_mode=Node.PROCESS_MODE_INHERIT
	print("ARCHITECTURE ",JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","failures":failures}))
	saves.quit_game(0 if failures.is_empty() else 1)
