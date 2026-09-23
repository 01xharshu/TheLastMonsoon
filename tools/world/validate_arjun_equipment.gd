extends SceneTree
var failed := false
var report: Dictionary = {}
func _initialize() -> void:
	call_deferred("validate")
func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
func key_event(code: int, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event
func validate() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_move_to_foreground()
	var world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 12: await process_frame
	world.set_physics_process(false)
	var player = world.get_node("Player")
	var visual = player.get_node("VisualRoot/CharacterVisual")
	var equipment = visual.equipment
	var wheel = player.get_node("UI/WeaponWheel")
	visual.set_process(false)
	check(equipment.stowed, "Initial state must carry both weapons stowed")
	check(equipment.talwar_waist.visible and equipment.enfield_back.visible, "Both stowed weapons must remain visible")
	visual._unhandled_key_input(key_event(KEY_H))
	check(equipment.talwar_hand.visible and not equipment.talwar_waist.visible, "H must draw selected talwar once")
	visual._unhandled_key_input(key_event(KEY_H))
	check(equipment.stowed, "H must stow talwar")
	# Hold/release keyboard path; arrow selection commits an Enfield.
	wheel._input(key_event(KEY_QUOTELEFT))
	check(wheel.visible and player.get_meta("weapon_wheel_open",false), "Hold ~ must open wheel")
	wheel._input(key_event(KEY_RIGHT))
	wheel._input(key_event(KEY_QUOTELEFT,false))
	check(not wheel.visible and equipment.enfield_hand.visible, "Release ~ must select and draw Enfield")
	check(not player.get_meta("weapon_wheel_open",false), "Wheel must release gameplay")
	# Pointer path and Escape rollback.
	wheel.open()
	wheel.select_from_pointer(wheel.size*.5+Vector2(0,-160))
	check(wheel.selected==0, "Top pointer sector must select talwar")
	wheel._input(key_event(KEY_ESCAPE))
	check(equipment.enfield_hand.visible, "Escape must preserve the previous weapon")
	# Guard map and inventory, including cancellation without changing selection.
	player.set_meta("map_open",true)
	wheel.open()
	check(not wheel.visible, "Wheel must not open over map")
	player.set_meta("map_open",false)
	player.inventory_ui.open_inventory()
	wheel.open()
	check(not wheel.visible, "Wheel must not open over inventory")
	player.inventory_ui.close_inventory()
	# Swimming keeps every hand copy hidden; changing selection cannot bypass it.
	player.is_swimming=true
	visual._process(1.0/60.0)
	check(equipment.stowed and not equipment.talwar_hand.visible and not equipment.enfield_hand.visible, "Swimming must force stow")
	visual._unhandled_key_input(key_event(KEY_H))
	check(equipment.stowed, "H must not draw underwater")
	wheel.open();wheel.selected=1;wheel.close(true)
	check(equipment.stowed, "Wheel cannot draw while swimming")
	player.is_swimming=false
	visual._process(1.0/60.0)
	check(equipment.stowed, "Leaving water must not automatically draw")
	visual._unhandled_key_input(key_event(KEY_H))
	for i in 30: visual._process(1.0/60.0)
	var errors: Dictionary = equipment.grip_errors()
	print("EQUIPMENT INPUT CHECKS FINISHED ", errors)
	report["rifle_grip"] = errors
	check(errors.right_palm_m<0.025 and errors.left_palm_m<0.025, "Both rifle grip targets must be reachable")
	player.set_physics_process(false)
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.fov=40
		camera.global_position=visual.model.to_global(Vector3(1.8,1.15,2.2))
		camera.look_at(visual.model.to_global(Vector3(0,0.95,0)))
		camera.make_current()
		player.get_node("UI").hide()
		for mode in ["enfield","stowed","talwar"]:
			print("CAPTURING ",mode)
			equipment.selected=1 if mode=="enfield" else 0
			equipment.stowed=mode=="stowed"
			equipment._refresh()
			for i in 30: visual._process(1.0/60.0)
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/characters/arjun/runtime_"+mode+".png")
		player.get_node("UI").show()
		player.set_physics_process(true)
		wheel.open()
		player.set_physics_process(false)
		wheel.selected=1;wheel.queue_redraw()
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/characters/arjun/weapon_wheel.png")
		wheel.close(false)
	report["result"]="FAIL" if failed else "PASS"
	report["checks"]=["H toggle","visible stowed gun and sword","wheel hold/release","arrow selection","pointer selection","Escape rollback","map/inventory exclusion","swim auto-stow","no underwater draw","no automatic redraw after swim"]
	var file := FileAccess.open("res://docs/characters/arjun/equipment_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("ARJUN EQUIPMENT ",JSON.stringify(report))
	quit(1 if failed else 0)
