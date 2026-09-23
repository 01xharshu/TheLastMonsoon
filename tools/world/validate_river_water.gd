extends SceneTree
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func validate() -> void:
	var layout := Layout.new()
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var player: CharacterBody3D = world.get_node("Player")
	var river: Node = player.get_node("RiverWaterComponent")
	var inventory: InventoryComponent = player.inventory
	var survival: SurvivalComponent = player.survival
	check(inventory.has_water_bag(),"Arjun did not start with a waist pouch")
	var bank := Vector3.ZERO
	var found := false
	for z in [180.0, 215.0, 235.0, 300.0, -100.0]:
		var edge: float = layout.river_x(z)-layout.river_width(z)
		for offset in range(0,90):
			var x: float = edge-float(offset)*0.5
			var y: float = layout.height(x,z)
			if y>0.2 and y<1.7:
				bank=Vector3(x,y+1.0,z)
				found=true
				break
		if found: break
	check(found,"No accessible riverbank candidate")
	if found:
		player.global_position=bank
		player.velocity=Vector3.ZERO
		for i in 20: await physics_frame
		check(player.is_on_floor(),"Riverbank does not support player")
		check(river.can_use_river(),"Grounded riverbank offers no water interaction")
		survival.hydration=45.0
		check(river.start_drink(),"Drink action did not start")
		check(player.get_meta("river_action","")=="drink","Drink pose state missing")
		if DisplayServer.get_name() != "headless":
			river._process(0.65)
			var camera: Camera3D = world.get_node("SurveyCamera")
			camera.global_position=bank+Vector3(-2.4,0.9,2.8)
			camera.look_at(bank+Vector3(0,-0.15,0))
			camera.make_current()
			player.get_node("UI").hide()
			for i in 20: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/world/captures/20_river_drink.png")
		river._process(2.0)
		check(survival.hydration>70.0,"Drinking did not restore hydration")
		check(player.get_meta("river_action","")=="","Drink action did not finish")
		check(river.start_fill(),"Pouch fill did not start")
		river._process(2.0)
		check(inventory.get_stored_water_liters()>1.9,"Pouch did not fill")
		check(not river.start_fill(),"Full pouch accepted refill")
		player.global_position=Vector3(-320,layout.height(-320,230)+1.0,230)
		for i in 12: await physics_frame
		check(not river.can_use_river(),"Distant land offered river interaction")
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","bank":bank,"hydration":survival.hydration,"pouch_liters":inventory.get_stored_water_liters(),"failures":failures}
	var file := FileAccess.open("res://docs/world/river_water_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("RIVER WATER VALIDATION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
