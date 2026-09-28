extends Node
var failures: Array[String] = []
var horse: CharacterBody3D
var actor: CharacterBody3D
var world: Node3D
var camera: Camera3D
func _ready() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)
func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame
func sag(side: String) -> float:
	var points: Array = horse.reins[side].points
	var chord: Vector3 = (points[0] as Vector3).lerp(points[horse.REIN_SEGMENTS] as Vector3, 0.5)
	return chord.y - (points[horse.REIN_SEGMENTS / 2] as Vector3).y
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	camera.global_position = horse.global_position + horse.global_basis * Vector3(-3.5, 2.8, 2.8)
	camera.look_at(horse.global_position + Vector3.UP * 1.6)
	camera.make_current()
	for i in 3: await get_tree().process_frame
	RenderingServer.force_draw(false)
	check(get_tree().root.get_texture().get_image().save_png("res://docs/world/captures/"+label+".png") == OK,label+" capture")
func run() -> void:
	world = preload("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	await frames(20)
	horse = world.get_node("VillageHorse")
	actor = world.get_node("Player")
	actor.set_process_unhandled_input(false)
	actor.get_node("UI").hide()
	world.get_node("LandscapeUI").hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	horse.global_position = Vector3(-258,world.layout.height(-258,203)+0.15,203)
	horse.rotation.y = 0
	actor.global_position = horse.global_position + Vector3(0,1,2)
	camera = Camera3D.new()
	world.add_child(camera)
	await frames(45)
	for side in ["l","r"]:
		var rope: Dictionary = horse.reins[side]
		check(rope.points.size() == horse.REIN_SEGMENTS+1 and rope.pieces.size() == horse.REIN_SEGMENTS,side+" has articulated rein")
		check(sag(side) > 0.03,side+" unmounted rein hangs below endpoint chord")
	var idle_sag := {"l":sag("l"),"r":sag("r")}
	check(horse.body_root.find_child("ReinFront",false,false) == null and horse.body_root.find_child("ReinBack",false,false) == null,"rigid rods removed")
	await capture("horse_reins_idle")
	check(horse.board(actor),"board horse for rein review")
	await frames(60)
	for side in ["l","r"]:
		var points: Array = horse.reins[side].points
		var anchors: Array[Vector3] = horse._rein_anchors(side)
		check((points[0] as Vector3).distance_to(anchors[0]) < 0.02 and (points[horse.REIN_SEGMENTS] as Vector3).distance_to(anchors[1]) < 0.02,side+" rein follows bit and rider hand")
	await capture("horse_reins_mounted")
	var old_mid: Vector3 = horse.reins["l"].points[horse.REIN_SEGMENTS/2]
	Input.action_press("move_forward")
	Input.action_press("move_left")
	await frames(50)
	Input.action_release("move_forward")
	Input.action_release("move_left")
	check(old_mid.distance_to(horse.reins["l"].points[horse.REIN_SEGMENTS/2]) > 0.5,"rein moves during ridden turn")
	for side in ["l","r"]:
		var points: Array = horse.reins[side].points
		var anchors: Array[Vector3] = horse._rein_anchors(side)
		check((points[0] as Vector3).distance_to(anchors[0]) < 0.02 and (points[horse.REIN_SEGMENTS] as Vector3).distance_to(anchors[1]) < 0.02,side+" moving endpoints stay attached")
	await capture("horse_reins_turn")
	var report := FileAccess.open("res://docs/world/horse_reins_validation.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","failures":failures,"segments_per_side":horse.REIN_SEGMENTS,"idle_sag_m":idle_sag},"\t")+"\n")
	print("HORSE REINS ","PASS" if failures.is_empty() else "FAIL")
	get_tree().quit(0 if failures.is_empty() else 1)
