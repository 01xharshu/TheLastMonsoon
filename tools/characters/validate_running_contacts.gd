extends SceneTree
## Deformed boot surface contact during input-driven sprint, jump and dodge.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var world:=Node3D.new();root.add_child(world);current_scene=world
	var clock:=preload("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
	var floor:=StaticBody3D.new();world.add_child(floor)
	var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(80,.2,80);collider.shape=shape;collider.position.y=-.1;floor.add_child(collider)
	var actor: CharacterBody3D=load("res://player/player.tscn").instantiate();world.add_child(actor);actor.position=Vector3(0,.9,0)
	actor.set_process_input(false);actor.set_process_unhandled_input(false)
	var visual: Node3D=actor.get_node("VisualRoot/CharacterVisual")
	var feet:=visual.get_node("LocomotionFootContact")
	for i in 8:await physics_frame
	Input.action_press("move_forward");Input.action_press("sprint")
	var minimum:=INF;var maximum:=-INF;var samples:=0;var ground_minimum:=INF
	for frame in 180:
		await process_frame
		if frame<15:continue
		var bounds: Dictionary=preload("res://tools/characters/skinned_ground_audit.gd").bounds(actor,visual.skeleton,"*Boot*")
		for item in bounds.values():ground_minimum=minf(ground_minimum,item.minimum_y)
		for side in feet.contacts:
			var suffix:="_1" if side=="l" else "_-1"
			var height: float=minf(bounds["Arjun_Boot"+suffix].minimum_y,bounds["Boot outsole "+("1" if side=="l" else "-1")].minimum_y)
			minimum=minf(minimum,height);maximum=maxf(maximum,height);samples+=1
	Input.action_release("move_forward");Input.action_press("move_right")
	for frame in 35:
		await process_frame
		var bounds: Dictionary=preload("res://tools/characters/skinned_ground_audit.gd").bounds(actor,visual.skeleton,"*Boot*")
		for item in bounds.values():ground_minimum=minf(ground_minimum,item.minimum_y)
	Input.action_release("move_right");Input.action_release("sprint")
	for frame in 30:
		await process_frame
		var bounds: Dictionary=preload("res://tools/characters/skinned_ground_audit.gd").bounds(actor,visual.skeleton,"*Boot*")
		for item in bounds.values():ground_minimum=minf(ground_minimum,item.minimum_y)
	Input.action_press("jump")
	for frame in 4:await process_frame
	Input.action_release("jump")
	var jump_release: bool=not actor.is_on_floor() and feet.contacts.is_empty()
	var passed:=samples>20 and minimum>=-.025 and maximum<.05 and ground_minimum>=-.025 and jump_release
	var report:={"status":"PASS" if passed else "FAIL","samples":samples,"minimum_planted_boot_y_m":minimum,"maximum_planted_boot_y_m":maximum,"all_ground_boot_minimum_y_m":ground_minimum,"jump_release":jump_release,"hardware_fps_verified":false,"visual_approved":false}
	FileAccess.open("res://docs/characters/arjun/running_sole_contacts.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RUNNING SOLE CONTACT ",report)
	preload("res://tools/test_audio_cleanup.gd").stop(root);world.queue_free();await process_frame;await process_frame
	await preload("res://tools/test_audio_cleanup.gd").settle(self)
	quit(0 if passed else 1)
