extends Node
var failures: Array[String] = []
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
	if DisplayServer.get_name() == "headless": return
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	check(get_tree().root.get_texture().get_image().save_png("res://docs/world/captures/"+label+".png") == OK, label+" capture")
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
	camera.global_position = compound.to_global(Vector3(-54,8,8))
	camera.look_at(horse.global_position+Vector3.UP*1.3)
	camera.make_current()
	check(horse.board(actor),"mount begins on raised landing")
	await frames(21)
	check(horse.transition == "mount" and actor.get_meta("horse_transition_progress",0.0) > 0.2,"mount has an intermediate pose")
	await capture("horse_mount_landing")
	await frames(40)
	check(horse.transition == "" and horse.rider == actor,"mount completes")
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
	check(horse.board(actor),"remount after landing dismount")
	await frames(60)
	# At this height both sides are open air; no remote terrain exit is allowed.
	horse.global_position = compound.to_global(Vector3(-40,4.9,5.1))
	horse.set_physics_process(false)
	check(not horse.dismount(),"dismount refuses unsupported exits")
	var report := FileAccess.open("res://docs/world/horse_transition_validation.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","failures":failures},"\t")+"\n")
	print("HORSE TRANSITIONS ","PASS" if failures.is_empty() else "FAIL")
	get_tree().quit(0 if failures.is_empty() else 1)
