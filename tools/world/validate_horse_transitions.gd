extends Node
var failures: Array[String] = []
const MountMotion = preload("res://player/arjun_horse_mount.gd")
const HorseSave = preload("res://horses/horse_save_state.gd")
var actor: CharacterBody3D
var horse: CharacterBody3D
var world: Node3D
func _ready() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)
func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame
func capture(label: String) -> void:
	var directory := OS.get_environment("TLM_MOUNT_REVIEW_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	var running := horse.is_physics_processing()
	horse.set_physics_process(false)
	for i in 3: await get_tree().process_frame
	RenderingServer.force_draw(false)
	check(get_tree().root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, label + " capture")
	horse.set_physics_process(running)

func bone_world(name: String, offset := Vector3.ZERO) -> Vector3:
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	var index: int = visual.skeleton.find_bone(name)
	return visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(index) * offset)

func boot_world(side: String) -> Vector3:
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	var rest: Transform3D = visual.skeleton.get_bone_global_rest(visual.skeleton.find_bone("foot_" + side))
	return bone_world("foot_" + side, rest.basis.inverse() * Vector3(0,-.085,.06))

func wait_mount(progress: float) -> void:
	for i in ceili(MountMotion.DURATION * Engine.physics_ticks_per_second) + 5:
		if actor.get_meta("horse_transition_progress", 0.0) >= progress: return
		await frames(1)

func check_mount(entry: float, label: String) -> void:
	var near := "l" if entry < 0.0 else "r"
	var far := "r" if entry < 0.0 else "l"
	await wait_mount(.29)
	check(horse.transition == "mount", label + " brace precedes seating")
	check(actor.get_meta("horse_transition_side", 0.0) == entry, label + " correct entry side")
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	check(visual.mount_upper != null and visual.mount_upper.mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED and visual.mount_upper.get_blend_shape_value(0) > .9, label + " reach eases the shirt sleeve")
	check(visual.mount_elbow_lining != null and visual.mount_elbow_lining.visible and visual.mount_elbow_lining.skin != null, label + " skinned elbow lining active during reach")
	check(visual.motion_tree.active and visual.motion_tree.get("parameters/horse_mount_side/blend_position") == entry, label + " mount AnimationTree branch active")
	var palm := bone_world("hand_" + near, visual.equipment.palm_offsets[near])
	var head: Vector3 = horse.tack_root.to_local(bone_world("head"))
	check(absf(head.x) > .47 or head.y > 1.99, label + " head clears the horse during brace " + str(head))
	var palm_gap: float = palm.distance_to(horse.saddle_grip_world(near, entry))
	check(palm_gap < .07, label + " brace palm reaches saddle (%.3fm)" % palm_gap)
	var braced_hip: Vector3 = horse.to_local(bone_world("pelvis"))
	await capture(label + "_brace")
	await wait_mount(.42)
	var loaded_foot_gap: float = boot_world(near).distance_to(horse.stirrup_world(near))
	check(loaded_foot_gap < .04, label + " loaded boot holds the tread (%.3fm)" % loaded_foot_gap)
	var loaded_palm_gap := bone_world("hand_" + near, visual.equipment.palm_offsets[near]).distance_to(horse.saddle_grip_world(near, entry))
	check(loaded_palm_gap < .04, label + " near hand holds through the push (%.3fm)" % loaded_palm_gap)
	await wait_mount(.56)
	for trousers: MeshInstance3D in visual.mount_trousers:
		check(trousers.mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED and trousers.get_blend_shape_value(0) > .95,
			label + " trouser corrective uses absolute shapes at full lift (%s mode=%s weight=%.3f)" % [trousers.name, trousers.mesh.blend_shape_mode, trousers.get_blend_shape_value(0)])
	var raised_hip: Vector3 = horse.to_local(bone_world("pelvis"))
	check(raised_hip.y > braced_hip.y + .20, label + " pelvis rises before seating")
	check(raised_hip.y > horse.to_local(horse.seat_world()).y + .20, label + " pelvis clears saddle")
	await capture(label + "_rise")
	await wait_mount(.70)
	var crossing_boot: Vector3 = horse.tack_root.to_local(boot_world(far))
	check(crossing_boot.y > 1.98 and crossing_boot.z > .35, label + " free boot arcs over rear saddle " + str(crossing_boot))
	await capture(label + "_cross")
	await wait_mount(.91)
	var rein_anchors: Array[Vector3] = horse._rein_anchors(near)
	var rein_palm := bone_world("hand_" + near, visual.equipment.palm_offsets[near])
	check(rein_anchors[1].distance_to(rein_palm) < .12, label + " rein follows hand before the seated handoff")
	await wait_mount(1.0)
	await frames(2)
	check(horse.transition == "" and horse.rider == actor, label + " mount completes")
	check(bone_world("pelvis").distance_to(horse.seat_world()) < .015, label + " pelvis settles onto saddle")
	check(visual.mount_trouser_ease == 0.0 and visual.mount_upper.get_blend_shape_value(0) == 0.0 and visual.mount_hem.get_blend_shape_value(0) == 0.0 and not visual.mount_elbow_lining.visible, label + " clothing correctives release into seated ride")
	for side in ["l", "r"]:
		check(boot_world(side).distance_to(horse.stirrup_world(side)) < .03, label + " seated boot stays on stirrup " + side)
	await capture(label + "_seated")
func run() -> void:
	world = preload("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	await frames(20)
	actor = world.get_node("Player")
	horse = world.get_node("VillageHorse")
	actor.set_process_unhandled_input(false)
	actor.get_node("UI").hide()
	world.get_node("LandscapeUI").hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var compound: Node3D = world.find_child("ColonialCompound",true,false)
	horse.global_position = compound.to_global(Vector3(-48.2,4.9,5.1))
	horse.rotation.y = 0.0
	actor.global_position = compound.to_global(Vector3(-49.7,5.75,5.1))
	actor.velocity = Vector3.ZERO
	await frames(20)
	var mask := actor.collision_mask
	var layer := actor.collision_layer
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.global_position = compound.to_global(Vector3(-52,7.6,7.2))
	camera.look_at(horse.global_position+Vector3.UP*1.3)
	camera.make_current()
	var interact := InputEventAction.new()
	interact.action = "secondary_interact"
	interact.pressed = true
	actor._unhandled_input(interact)
	check(horse.rider == actor and horse.transition == "mount", "existing secondary interaction begins mount on raised landing")
	await check_mount(-1.0, "left")
	check(actor.interaction_overlay.ride_prompt == "Dismount horse","exit card remains visible after mount")
	check(horse.dismount(),"dismount finds raised landing surface")
	check(absf(horse.transition_to.y-compound.to_global(Vector3(0,5.74,0)).y) < 0.12,"dismount target stays on landing height")
	await frames(21)
	check(horse.transition == "dismount","dismount has an intermediate pose")
	await capture("horse_dismount_landing")
	await frames(50)
	check(horse.rider == null and actor.is_on_floor(),"dismount settles on landing")
	check(actor.collision_mask == mask and actor.collision_layer == layer,"dismount restores collision")
	check(not actor.has_meta("mounted_vehicle"),"dismount releases mounted state")
	await capture("horse_dismount_complete")
	actor.global_position = horse.global_position + horse.global_basis.x * 1.45 + Vector3.UP * 0.94
	actor.velocity = Vector3.ZERO
	await frames(10)
	check(horse.board(actor),"remount from opposite side")
	camera.global_position = horse.to_global(Vector3(3.5, 2.9, 2.6))
	camera.look_at(horse.global_position + Vector3.UP * 1.6)
	await check_mount(1.0, "right")
	# At this height both sides are open air; no remote terrain exit is allowed.
	horse.global_position = compound.to_global(Vector3(-40,4.9,5.1))
	horse.set_physics_process(false)
	check(not horse.dismount(),"dismount refuses unsupported exits")
	horse.global_position = compound.to_global(Vector3(-48.2,4.9,5.1))
	horse.set_physics_process(true)
	await frames(20)
	var saved := HorseSave.collect(world)
	check(horse.dismount(), "dismount before applying the saved riding state")
	await frames(55)
	HorseSave.restore(world, saved)
	await frames(2)
	check(horse.rider == actor and horse.transition == "", "restored horse is seated immediately")
	check(bone_world("pelvis").distance_to(horse.seat_world()) < .015, "restored pelvis is on the saddle")
	Input.action_press("move_forward")
	await frames(15)
	Input.action_release("move_forward")
	check(horse.pace > .5, "seated rider can drive horse after restore")
	print("HORSE TRANSITIONS ", "PASS" if failures.is_empty() else "FAIL")
	await SaveManager.quit_game(0 if failures.is_empty() else 1)
