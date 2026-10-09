extends SceneTree
## Caller owns the OS temporary save directory and deletes it in finally.
var saves: Node
func _initialize() -> void: run.call_deferred()
func run() -> void:
	saves = root.get_node("SaveManager")
	var directory := OS.get_environment("TLM_GATE_SAVE_TEST_DIR")
	if directory.is_empty():
		push_error("Supply an OS temporary TLM_GATE_SAVE_TEST_DIR")
		quit(1)
		return
	saves.save_root = directory
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for frame in 8: await process_frame
	var actor: CharacterBody3D = world.get_node("Player")
	actor.set_physics_process(false)
	var gate: Node3D
	for node in get_nodes_in_group("house_doors"):
		if node.name == "CourtyardGate" and node.outside_latch_access:
			gate = node
			break
	assert(gate != null,"No placed courtyard gate")
	var path: NodePath = world.get_path_to(gate)
	gate.restore_state(false)
	gate.manual_locked = true
	gate.locked = true
	actor.global_position = gate.to_global(Vector3(0,.94,1.4))
	assert(saves.save_game(world,1),"Could not save placed gate")
	assert(saves.start_loaded_game(saves.newest_slot()),"Continue rejected gate slot")
	for frame in 16: await process_frame
	world = current_scene
	assert(world != null and world.has_node(path),"Continue did not rebuild gate world")
	gate = world.get_node(path)
	actor = world.get_node("Player")
	actor.set_physics_process(false)
	assert(saves.pending_slot == -1,"World did not consume pending save")
	assert(gate.manual_locked and gate.locked and not gate.opened,"Continue lost the manual gate lock")
	actor.global_position = gate.to_global(Vector3(0,.94,1.4))
	assert(not gate.is_inside(actor.global_position),"Continue test approached inside")
	gate.interact(actor)
	for frame in 300:
		await physics_frame
		if gate.opened and not gate.moving: break
	assert(gate.opened,"Restored locked gate failed outside reopening")
	actor.global_position = gate.to_global(Vector3(0,.94,3.5))
	gate.auto_close_delay = .3
	for frame in 300:
		await physics_frame
		if not gate.opened and not gate.moving: break
	assert(not gate.opened and gate.manual_locked,"Continued gate failed automatic close/lock retention")
	print("GATE CONTINUE: PASS | populated-world save, fresh scene Continue, restored outside lock/reopen/auto-close")
	await saves.quit_game(0)
