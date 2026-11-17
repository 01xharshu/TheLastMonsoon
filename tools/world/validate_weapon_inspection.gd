extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)
func run() -> void:
	root.size=Vector2i(1280,720)
	var world:=Node3D.new();root.add_child(world);current_scene=world
	var clock: Node=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
	var actor: CharacterBody3D=load("res://player/player.tscn").instantiate();world.add_child(actor)
	for frame in 5:await physics_frame
	actor.set_physics_process(false)
	var pickup: Interactable=load("res://world/suryagarh/settlements/weapon_pickup.gd").new()
	pickup.weapon_id="enfield";world.add_child(pickup)
	var gun: Node3D=load("res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb").instantiate();pickup.add_child(gun)
	var gear: Node=actor.get_node("VisualRoot/CharacterVisual").equipment
	var previous: int=gear.selected
	var original_mouse: int=Input.mouse_mode
	pickup.interact(actor)
	var window: Node=actor.get_node("UI").get_children().back()
	check(paused and actor.get_meta("weapon_inspection_open",false),"inspection freezes gameplay and captures modal ownership")
	check(not actor.inventory.has_item("enfield") and not pickup.taken,"opening inspection grants nothing and keeps original weapon")
	check(window.pivot.get_child_count()>0 and window.camera.get_world_3d()!=actor.get_world_3d(),"real weapon meshes rendered in isolated 3D world")
	var rotation_before: Vector3=window.pivot.rotation
	var motion:=InputEventMouseMotion.new();motion.button_mask=MOUSE_BUTTON_MASK_LEFT;motion.relative=Vector2(40,20);window.preview_input(motion)
	check(window.pivot.rotation!=rotation_before,"drag rotates 3D weapon")
	var scroll:=InputEventMouseButton.new();scroll.pressed=true;scroll.button_index=MOUSE_BUTTON_WHEEL_UP
	var zoom_before: float=window.camera.position.z;window.preview_input(scroll)
	check(window.camera.position.z<zoom_before,"scroll zooms inspection camera")
	if OS.get_environment("TLM_GLOW_REVIEW")!="":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TLM_GLOW_REVIEW")+"/inspection.png")
	window.buttons[0].pressed.emit();await process_frame
	check(not paused and is_instance_valid(pickup) and not pickup.taken and not actor.inventory.has_item("enfield"),"Leave returns to game without taking weapon")
	pickup.interact(actor);window=actor.get_node("UI").get_children().back()
	var escape:=InputEventAction.new();escape.action="ui_cancel";escape.pressed=true;window._input(escape)
	check(not paused and Input.mouse_mode==original_mouse and not pickup.taken,"Escape restores original mouse mode and leaves pickup untouched")
	await process_frame
	pickup.interact(actor);window=actor.get_node("UI").get_children().back();window.buttons[1].pressed.emit()
	check(actor.inventory.has_item("enfield") and pickup.taken and gear.selected==previous,"Keep stores weapon without changing selected equipment")
	check(actor.inventory.get_item_count("paper_cartridges")==24,"confirmed acquisition retains bundled ammunition")
	await process_frame
	var pistol: Interactable=load("res://world/suryagarh/settlements/weapon_pickup.gd").new();pistol.weapon_id="pistol";world.add_child(pistol)
	var model: Node3D=load("res://environment/weapons/adams_1851/adams_1851.glb").instantiate();pistol.add_child(model)
	pistol.interact(actor);window=actor.get_node("UI").get_children().back();window.buttons[2].pressed.emit()
	check(actor.inventory.has_item("pistol") and gear.selected==3 and pistol.taken,"Equip stores and selects confirmed weapon")
	await process_frame
	var duplicate: Interactable=load("res://world/suryagarh/settlements/weapon_pickup.gd").new();duplicate.weapon_id="pistol";world.add_child(duplicate)
	duplicate.interact(actor);window=actor.get_node("UI").get_children().back();window.confirm(true);window.confirm(true)
	check(actor.inventory.get_item_count("pistol")==1 and not duplicate.taken,"repeated confirmation never duplicates existing weapon")
	await process_frame
	duplicate.interact(actor);window=actor.get_node("UI").get_children().back();duplicate.queue_free();await process_frame;await process_frame
	check(not paused and not actor.get_meta("weapon_inspection_open",false),"removed pickup safely closes inspection and restores gameplay")
	await process_frame
	var supply: Interactable=load("res://world/suryagarh/settlements/supply_pickup.gd").new();supply.item_id="utility_knife";supply.count=1;world.add_child(supply)
	supply.interact(actor);window=actor.get_node("UI").get_children().back()
	check(paused and not actor.inventory.has_item("utility_knife"),"displayed supply weapons also open inspection before acquisition")
	window.confirm(true)
	check(supply.taken and gear.selected==4 and actor.inventory.has_item("utility_knife"),"displayed knife Equip uses existing equipment slot")
	await process_frame
	var kit: Node=load("res://player/chacha_kit.gd").new();kit.name="ChachaKit";actor.add_child(kit)
	for frame in 3:await process_frame
	var rack: Interactable=load("res://world/suryagarh/settlements/chacha_rack.gd").new();rack.item_id="spear";world.add_child(rack)
	rack.interact(actor);window=actor.get_node("UI").get_children().back();window.confirm(false)
	check(actor.inventory.has_item("spear") and is_instance_valid(rack) and gear.selected==4,"family rack Keep retains reusable family stock and selected weapon")
	await process_frame
	var ammo: Interactable=load("res://world/suryagarh/settlements/supply_pickup.gd").new();world.add_child(ammo)
	var reserve_before: int=actor.inventory.get_item_count("paper_cartridges")
	ammo.interact(actor)
	check(not paused and actor.inventory.get_item_count("paper_cartridges")==reserve_before+6,"ordinary ammunition keeps direct collection flow")
	print("WEAPON INSPECTION ","PASS" if failures.is_empty() else "FAIL",failures)
	await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures.is_empty() else 1)
