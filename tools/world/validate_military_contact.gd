extends SceneTree
var world: Node3D
var player: CharacterBody3D
var fort: Node3D
var checks: Array[Dictionary] = []
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks.append({"check":label,"pass":ok})
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func walk(label: String,points: Array[Vector3]) -> void:
	player.global_position = fort.to_global(points[0])+Vector3.UP*player.get_node("CollisionShape3D").shape.height*.5
	player.velocity = Vector3.ZERO
	await physics_frame
	var passed := true
	for target_local in points.slice(1):
		var target: Vector3 = fort.to_global(target_local)
		var reached := false
		for frame in 900:
			var delta := target-player.global_position
			delta.y=0
			if delta.length()<.3:
				reached=true
				break
			var motion := delta.normalized()*3.5
			player.velocity=motion+Vector3(0,-2,0)
			player.move_and_slide()
			player.call("_try_walk_step",1.0/60.0,motion/60.0)
			await physics_frame
		if not reached:
			passed=false
			print("BLOCKED ",label," at ",fort.to_local(player.global_position))
			break
	check(passed,label)
func capture(label: String,eye: Vector3,target: Vector3) -> void:
	if DisplayServer.get_name()=="headless":return
	var camera:=Camera3D.new()
	world.add_child(camera)
	camera.global_position=fort.to_global(eye)
	camera.look_at(fort.to_global(target))
	camera.make_current()
	for frame in 6:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/world/captures/military_"+label+".png")
	camera.queue_free()
func _run() -> void:
	world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	player=world.get_node("Player")
	fort=world.get_node("Settlement/GovernmentHouse")
	world.get_node("GameTimeSystem").clock_paused=true
	for frame in 12:await physics_frame
	player.set_physics_process(false)
	player.get_node("UI").hide()
	fort.get_node("FortEntranceGate").restore_state(true)
	for frame in 90:await physics_frame
	await walk("gate between guard stations",[Vector3(0,.04,98),Vector3(0,.04,82)])
	await walk("east cannon bypass",[Vector3(69,.04,51),Vector3(73,.04,51),Vector3(73,.04,39),Vector3(69,.04,39)])
	await walk("armoury step entry and exit",[Vector3(69,.04,-29),Vector3(69,.42,-34),Vector3(69,.42,-40),Vector3(69,.42,-34),Vector3(69,.04,-29)])
	var armoury:Node3D=fort.get_node("FortArmoury")
	var guns:=0
	var rifle_bounds:Array[AABB]=[]
	for child in armoury.get_children():
		if child is Node3D and child.scene_file_path.ends_with("weapon_enfield_p53_01.glb"):
			guns+=1
			var bounds:AABB=fort.weapon_bounds(child,armoury)
			check(absf(bounds.position.y-.6)<.01,"rifle %d support height"%guns)
			check(bounds.size.y>1.0 and bounds.size.x<.3,"rifle upright and separate")
			for previous in rifle_bounds:check(not previous.intersects(bounds),"rifle displays do not overlap")
			rifle_bounds.append(bounds)
	check(guns==6,"six fitted rifle displays")
	check(get_nodes_in_group("fort_cannons").size()==2,"both cannons constructed")
	var shelves:=0
	for child in armoury.get_children():
		if child.get_meta("part_label","")=="ArmourySideShelf":shelves+=1
	check(shelves==6,"six armoury shelves constructed")
	var linen_beds:=0
	for room in world.get_node("Settlement/BritishCantonment").get_children():
		linen_beds+=int(room.get_meta("linen_bed_count",0))
	check(linen_beds==40,"all forty cantonment beds receive linen")
	for cannon in get_nodes_in_group("fort_cannons"):
		var bounds:AABB=fort.weapon_bounds(cannon,cannon)
		print("CANNON BOUNDS ",cannon.name," ",bounds)
		check(bounds.position.y>=-.1,"cannon above ground "+str(cannon.name))
	player.global_position=Vector3(0,50,0)
	var district:Node3D=world.get_node("Settlement/BritishCantonment")
	await capture("cantonment_exterior",fort.to_local(district.to_global(Vector3(-27,3,-30))),fort.to_local(district.to_global(Vector3(-43,1,-46))))
	await capture("cot_linen",fort.to_local(district.to_global(Vector3(-49,1.45,-45.6))),fort.to_local(district.to_global(Vector3(-49,.88,-47.7))))
	await capture("barracks_interior",fort.to_local(district.to_global(Vector3(-43,2,-42))),fort.to_local(district.to_global(Vector3(-48,1,-48))))
	await capture("officers_interior",fort.to_local(district.to_global(Vector3(43,2,-42))),fort.to_local(district.to_global(Vector3(50,1,-47))))
	await capture("armoury",Vector3(69,2.3,-34),Vector3(69,1.1,-44))
	await capture("cannon",Vector3(75,2.5,51),Vector3(69,.8,45))
	await capture("guards",Vector3(12,2.0,82),Vector3(8,1,87))
	var report:={"date":"2026-10-05","renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures,"open":"normal-speed character contact, guard response, cannon operation, final art"}
	var file:=FileAccess.open("res://docs/world/military_contact_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("MILITARY CONTACT ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
