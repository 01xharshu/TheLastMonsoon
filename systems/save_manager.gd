extends Node
## Versioned local saves and persistent settings. No generated world data is saved.
const WORLD := "res://world/suryagarh/suryagarh_world.tscn"
const SAVE_DIR := "user://saves"
const SETTINGS_FILE := "user://settings.cfg"
const SLOT_COUNT := 3
const VERSION := 1
const DEFAULTS := {
	"master": 0.8, "music": 0.55, "mouse": 1.0,
	"camera_distance": 1.25, "aim_camera_distance": 0.55,
	"fullscreen": false, "vsync": true, "input_device": "auto",
	"graphics_quality": 2, "key_bindings": {},
	"vibration": 0.65, "controller_light": true, "gyro_aim": false,
}
signal input_device_changed(device: String)
var active_input_device := "keyboard_mouse"
var active_joypad_id := -1
var _original_input_events: Dictionary = {}
var options: Dictionary = DEFAULTS.duplicate(true)
var pending_slot := -1
var save_root := SAVE_DIR
var settings_path := SETTINGS_FILE

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_options()
	_add_combat_actions()
	_cache_input_events()
	_restore_bindings()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_select_input_device()
	apply_options()
	get_viewport().size_changed.connect(_update_render_budget)
	_update_render_budget.call_deferred()

func _input(event: InputEvent) -> void:
	if options.input_device != "auto": return
	if event is InputEventJoypadButton and event.pressed:
		active_joypad_id = event.device
		_set_active_input_device("controller")
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.55:
		active_joypad_id = event.device
		_set_active_input_device("controller")
	elif event is InputEventKey and event.pressed and not event.echo:
		_set_active_input_device("keyboard_mouse")
	elif event is InputEventMouseButton and event.pressed:
		_set_active_input_device("keyboard_mouse")
	elif event is InputEventMouseMotion and event.relative.length() > 4.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_set_active_input_device("keyboard_mouse")

func _cache_input_events() -> void:
	for action in InputMap.get_actions():
		_original_input_events[action] = InputMap.action_get_events(action)

func _select_input_device() -> void:
	var preference: String = str(options.get("input_device", "auto"))
	var pads := Input.get_connected_joypads()
	if active_joypad_id not in pads: active_joypad_id = pads[0] if not pads.is_empty() else -1
	if preference == "controller" and not pads.is_empty():
		_set_active_input_device("controller")
	elif preference == "auto" and not pads.is_empty():
		_set_active_input_device("controller")
	else:
		_set_active_input_device("keyboard_mouse")

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_select_input_device()

func _set_active_input_device(device: String) -> void:
	if active_input_device == device and not _original_input_events.is_empty() and _input_map_applied: return
	active_input_device = device
	for action in _original_input_events:
		if str(action).begins_with("ui_"): continue
		InputMap.action_erase_events(action)
		for event in _original_input_events[action]:
			if (event is InputEventJoypadButton or event is InputEventJoypadMotion) == (device == "controller"):
				InputMap.action_add_event(action, event)
	_input_map_applied = true
	input_device_changed.emit(device)

var _input_map_applied := false

func _add_combat_actions() -> void:
	for action in ["attack", "aim", "reload", "weapon_wheel", "open_map", "stow_weapon", "context_modifier", "next_weapon", "identity_scroll"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var attack_mouse := InputEventMouseButton.new()
	attack_mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack",attack_mouse)
	var attack_pad := InputEventJoypadMotion.new()
	attack_pad.axis = JOY_AXIS_TRIGGER_RIGHT
	attack_pad.axis_value = 1.0
	InputMap.action_add_event("attack",attack_pad)
	var aim_mouse := InputEventMouseButton.new()
	aim_mouse.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("aim",aim_mouse)
	var aim_pad := InputEventJoypadMotion.new()
	aim_pad.axis = JOY_AXIS_TRIGGER_LEFT
	aim_pad.axis_value = 1.0
	InputMap.action_add_event("aim",aim_pad)
	var reload_key := InputEventKey.new()
	reload_key.physical_keycode = KEY_R
	InputMap.action_add_event("reload",reload_key)
	var reload_pad := InputEventJoypadButton.new()
	reload_pad.button_index = JOY_BUTTON_B
	InputMap.action_add_event("reload",reload_pad)
	_add_key_action("weapon_wheel",KEY_QUOTELEFT)
	_add_pad_button_action("weapon_wheel",JOY_BUTTON_DPAD_RIGHT)
	# Escape / Options owns the map menu; M and D-pad-left are freed.
	_add_key_action("stow_weapon",KEY_H)
	_add_pad_button_action("stow_weapon",JOY_BUTTON_DPAD_UP)
	_add_pad_button_action("context_modifier",JOY_BUTTON_LEFT_SHOULDER)
	_add_pad_button_action("next_weapon",JOY_BUTTON_RIGHT_SHOULDER)
	_add_key_action("identity_scroll",KEY_O)
	_add_key_action("identity_scroll",KEY_M)
	_add_pad_button_action("identity_scroll",JOY_BUTTON_DPAD_LEFT)
	_add_pad_button_action("identity_scroll",JOY_BUTTON_TOUCHPAD)

func _add_key_action(action: String, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action,event)

func _add_pad_button_action(action: String, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action,event)

func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [save_root,slot]

func read_slot(slot: int) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT: return {}
	var path := slot_path(slot)
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return {}
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("version",-1)!=VERSION: return {}
	if not data.get("position") is Array or data.position.size()!=3: return {}
	return data

func newest_slot() -> int:
	var slot := 0
	var timestamp := -1
	for candidate in range(1,SLOT_COUNT+1):
		var data := read_slot(candidate)
		if not data.is_empty() and int(data.get("saved_at",0))>timestamp:
			slot = candidate
			timestamp = int(data.saved_at)
	return slot

func slot_label(slot: int) -> String:
	var data := read_slot(slot)
	if data.is_empty(): return "Slot %d  ·  Empty" % slot
	var minutes := int(data.get("game_minutes",0))
	return "Slot %d  ·  Day %d, %02d:%02d" % [slot,minutes/1440+1,(minutes%1440)/60,minutes%60]

func save_game(world: Node3D, slot: int) -> bool:
	if slot < 1 or slot > SLOT_COUNT: return false
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_root))!=OK: return false
	var actor: CharacterBody3D = world.get_node("Player")
	if not actor.is_inside_tree(): return false
	var inventory: InventoryComponent = actor.get_node("InventoryComponent")
	var survival: SurvivalComponent = actor.get_node("SurvivalComponent")
	var equipment: Node3D = actor.get_node("VisualRoot/CharacterVisual").equipment
	var p: Vector3 = actor.global_position
	var data := {
		"version": VERSION, "saved_at": int(Time.get_unix_time_from_system()),
		"position": [p.x,p.y,p.z], "rotation_y": actor.rotation.y,
		"camera_pitch": actor.camera_pitch,
		"game_minutes": world.get_node("GameTimeSystem").total_game_minutes,
		"items": inventory.items.duplicate(true),
		"health": actor.health,
		"water_liters": inventory.stored_water_liters,
		"survival": {
			"hydration":survival.hydration,"satiety":survival.satiety,
			"energy":survival.energy,"warmth":survival.warmth,"stamina":survival.stamina,
		},
		"weapon": {"selected":int(equipment.selected),"stowed":equipment.stowed,
			"rifle_rounds":actor.get_node("RifleCombat").rounds,
			"rifle_reload":actor.get_node("RifleCombat").reload_remaining,
			"rifle_pending":actor.get_node("RifleCombat").pending_rounds,
			"pistol_reload":actor.get_node("PistolCombat").reload_remaining,
			"double_gun_reload":actor.get_node("DoubleGunCombat").reload_remaining,
			"double_gun_pending":actor.get_node("DoubleGunCombat").pending_rounds,
			"pistol_rounds":actor.get_node("PistolCombat").rounds,
			"double_gun_rounds":actor.get_node("DoubleGunCombat").rounds},
		"remaining_weapon_ids": _remaining_weapon_pickup_ids(world),
		"remaining_ammunition_ids": _remaining_ammunition_ids(world),
		"remaining_medical_ids": _remaining_medical_ids(world),
		"remaining_household_ids": _remaining_household_ids(world),
		"opened_treasure_chests": _opened_treasure_chest_ids(world),
		"door_states": _door_states(world),
		"cart_states": preload("res://vehicles/cart_save_state.gd").collect(world),
		"household_cattle": _cattle_states(world),
		"river_routines": preload("res://world/suryagarh/settlements/river_routine_save.gd").collect(world),
		"collected_forage_ids": _collected_forage_ids(world),
	}
	if world.has_node("ErrandSystem"):
		data["errands"] = world.get_node("ErrandSystem").export_state()
	data["administrative_services"] = _administrative_service_states(world)
	data["institution_operations"] = _institution_states(world)
	var fame := actor.get_node_or_null("FameComponent")
	if fame != null: data["fame"] = {"points":fame.points,"witnessed_deeds":fame.witnessed_deeds}
	var map: Control = actor.get_node("UI/WorldMap")
	if is_finite(map.waypoint.x):
		data["waypoint"] = [map.waypoint.x,map.waypoint.y]
		data["waypoint_site"] = map.selected_site
	var temp := slot_path(slot)+".tmp"
	var file := FileAccess.open(temp,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data,"\t")+"\n")
	file.flush()
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(slot_path(slot)))==OK

func start_new_game() -> void:
	pending_slot = 0
	get_tree().change_scene_to_file(WORLD)

func start_loaded_game(slot: int) -> bool:
	if read_slot(slot).is_empty(): return false
	pending_slot = slot
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD)
	return true

func apply_pending(world: Node3D) -> void:
	apply_options(world)
	if pending_slot <= 0:
		var is_new_game := pending_slot == 0
		pending_slot = -1
		if is_new_game:
			var opening := preload("res://story/opening_sequence.gd").new()
			opening.name = "OpeningSequence"
			world.add_child(opening)
			opening.start(world)
		return
	var data := read_slot(pending_slot)
	pending_slot = -1
	if data.is_empty(): return
	var actor: CharacterBody3D = world.get_node("Player")
	var coords: Array = data.position
	var x := clampf(float(coords[0]),-860.0,860.0)
	var z := clampf(float(coords[2]),-860.0,860.0)
	var y := float(coords[1])
	if world.layout.height(x,z)>0.0: y = maxf(y,world.layout.height(x,z)+0.9)
	actor.global_position = Vector3(x,y,z)
	actor.velocity = Vector3.ZERO
	actor.rotation.y = float(data.get("rotation_y",0.0))
	actor.camera_pitch = clampf(float(data.get("camera_pitch",0.0)),-1.2,1.1)
	actor.get_node("CameraPivot").rotation.x = actor.camera_pitch
	var time: Node = world.get_node("GameTimeSystem")
	time.total_game_minutes = maxf(0.0,float(data.get("game_minutes",540.0)))
	time._update_readable_time(true)
	var inventory: InventoryComponent = actor.get_node("InventoryComponent")
	actor.health = clampf(float(data.get("health",actor.MAX_HEALTH)),0.0,actor.MAX_HEALTH)
	inventory.items = data.get("items",{}).duplicate(true)
	if world.has_node("ErrandSystem") and data.get("errands",{}) is Dictionary:
		world.get_node("ErrandSystem").restore_state(data.get("errands",{}))
	var fame := actor.get_node_or_null("FameComponent")
	var saved_fame: Dictionary = data.get("fame",{})
	if fame != null:
		fame.points = maxi(0,int(saved_fame.get("points",0)))
		fame.witnessed_deeds = maxi(0,int(saved_fame.get("witnessed_deeds",0)))
	if not inventory.has_water_bag(): inventory.items["water_bag"] = 1
	inventory.stored_water_liters = clampf(float(data.get("water_liters",0.0)),0.0,inventory.get_total_water_capacity_liters())
	inventory.inventory_changed.emit()
	inventory._emit_water_changed()
	var survival: SurvivalComponent = actor.get_node("SurvivalComponent")
	var vitals: Dictionary = data.get("survival",{})
	for key in ["hydration","satiety","energy","warmth","stamina"]:
		survival.set(key,clampf(float(vitals.get(key,survival.get(key))),0.0,float(survival.get("max_"+key))))
	survival.hydration_changed.emit(survival.hydration,survival.max_hydration)
	survival.satiety_changed.emit(survival.satiety,survival.max_satiety)
	survival.energy_changed.emit(survival.energy,survival.max_energy)
	survival.warmth_changed.emit(survival.warmth,survival.max_warmth)
	survival.stamina_changed.emit(survival.stamina,survival.max_stamina)
	var equipment: Node3D = actor.get_node("VisualRoot/CharacterVisual").equipment
	var weapon: Dictionary = data.get("weapon",{})
	equipment.selected = clampi(int(weapon.get("selected",0)),0,5)
	equipment.stowed = bool(weapon.get("stowed",true))
	equipment._refresh()
	actor.get_node("RifleCombat").rounds = clampi(int(weapon.get("rifle_rounds",1)),0,1)
	actor.get_node("RifleCombat").loaded = actor.get_node("RifleCombat").rounds > 0
	actor.get_node("PistolCombat").rounds = clampi(int(weapon.get("pistol_rounds",5)),0,5)
	actor.get_node("DoubleGunCombat").rounds = clampi(int(weapon.get("double_gun_rounds",0)),0,2)
	actor.get_node("DoubleGunCombat").loaded = actor.get_node("DoubleGunCombat").rounds > 0
	for entry in [["RifleCombat","rifle",5.0,1],["DoubleGunCombat","double_gun",4.4,2]]:
		var firearm: Node = actor.get_node(entry[0])
		firearm.reload_remaining = clampf(float(weapon.get(entry[1]+"_reload",0.0)),0.0,entry[2])
		firearm.pending_rounds = clampi(int(weapon.get(entry[1]+"_pending",0)),0,entry[3]-firearm.rounds) if firearm.reload_remaining > 0.0 else 0
	actor.get_node("PistolCombat").reload_remaining = clampf(float(weapon.get("pistol_reload",0.0)),0.0,3.8)
	restore_household_pickups(world,data)
	if data.get("remaining_medical_ids") is Array:
		for pickup in world.get_tree().get_nodes_in_group("medical_supplies"):
			if world.is_ancestor_of(pickup) and not pickup.persistence_id() in data.remaining_medical_ids:
				pickup.queue_free()
	if data.get("remaining_ammunition_ids") is Array:
		for pickup in world.get_tree().get_nodes_in_group("ammunition_pickups"):
			if world.is_ancestor_of(pickup) and not pickup.persistence_id() in data.remaining_ammunition_ids:
				pickup.queue_free()
	if data.has("remaining_weapon_ids"):
		var remaining: Array = data.remaining_weapon_ids
		for pickup in world.get_tree().get_nodes_in_group("weapon_pickups"):
			if not pickup.persistence_id() in remaining:
				pickup.queue_free()
	elif data.has("remaining_weapon_pickups"):
		# Older saves used engine-generated paths, which change when room props
		# are added. Preserve unowned weapons and suppress already acquired ones.
		for pickup in world.get_tree().get_nodes_in_group("weapon_pickups"):
			if inventory.has_item(pickup.weapon_id): pickup.queue_free()
	for chest in world.get_tree().get_nodes_in_group("treasure_chests"):
		if String(chest.get_path()) in data.get("opened_treasure_chests",[]):
			chest.restore_opened()
	_restore_door_states(world,data.get("door_states",{}))
	preload("res://vehicles/cart_save_state.gd").restore(world,data.get("cart_states",[]))
	for service in world.get_tree().get_nodes_in_group("administrative_services"):
		var key := str(world.get_path_to(service))
		service.restore_state(data.get("administrative_services",{}).get(key,{}))
	_restore_cattle_states(world,data.get("household_cattle",{}))
	preload("res://world/suryagarh/settlements/river_routine_save.gd").restore(world,data.get("river_routines",{}))
	for operations in world.get_tree().get_nodes_in_group("institution_operations"):
		if not world.is_ancestor_of(operations): continue
		var key := str(world.get_path_to(operations))
		operations.restore_state(data.get("institution_operations",{}).get(key,{}))
	# Absent in older version-1 saves: preserve their available fruit.
	if data.get("collected_forage_ids") is Array:
		for grove in world.get_tree().get_nodes_in_group("forage_groves"):
			if world.is_ancestor_of(grove):
				grove.restore_collected(data.collected_forage_ids)
	var map: Control = actor.get_node("UI/WorldMap")
	if data.get("waypoint") is Array and data.waypoint.size()==2:
		map.waypoint = Vector2(float(data.waypoint[0]),float(data.waypoint[1]))
		map.selected_site = str(data.get("waypoint_site",""))

func _collected_forage_ids(world: Node3D) -> Array[String]:
	var ids: Array[String] = []
	for grove in world.get_tree().get_nodes_in_group("forage_groves"):
		if not world.is_ancestor_of(grove): continue
		for forage_id in grove.collected_ids:
			if not forage_id in ids: ids.append(forage_id)
	ids.sort()
	return ids

func _remaining_weapon_pickup_ids(world: Node3D) -> Array[String]:
	var remaining: Array[String] = []
	for pickup in world.get_tree().get_nodes_in_group("weapon_pickups"):
		if is_instance_valid(pickup) and not pickup.is_queued_for_deletion():
			remaining.append(pickup.persistence_id())
	return remaining

func _remaining_ammunition_ids(world: Node3D) -> Array[String]:
	var remaining: Array[String] = []
	for pickup in world.get_tree().get_nodes_in_group("ammunition_pickups"):
		if world.is_ancestor_of(pickup) and not pickup.is_queued_for_deletion():
			remaining.append(pickup.persistence_id())
	return remaining

func _opened_treasure_chest_ids(world: Node3D) -> Array[String]:
	var opened: Array[String] = []
	for chest in world.get_tree().get_nodes_in_group("treasure_chests"):
		if is_instance_valid(chest) and chest.opened:
			opened.append(String(chest.get_path()))
	return opened

func load_options() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path)!=OK: return
	for key in DEFAULTS:
		options[key] = config.get_value("settings",key,DEFAULTS[key])
	# Former default values follow the reference third-person framing.
	if is_equal_approx(float(options.camera_distance), 2.0) or is_equal_approx(float(options.camera_distance), 1.8):
		options.camera_distance = 1.25
	if not options.input_device in ["auto", "keyboard_mouse", "controller"]:
		options.input_device = "auto"
	options.vibration = clampf(float(options.vibration),0.0,1.0)
	options.camera_distance = clampf(float(options.camera_distance),1.25,4.0)
	options.aim_camera_distance = clampf(float(options.aim_camera_distance),0.5,2.0)

func set_option(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key): return
	options[key] = value
	if key == "input_device": _select_input_device()
	if key == "vibration" and float(value) <= 0.0 and get_node_or_null("/root/ControllerFeedback"):
		get_node("/root/ControllerFeedback").stop()
	var config := ConfigFile.new()
	for item in options: config.set_value("settings",item,options[item])
	config.save(settings_path)
	apply_options(get_tree().current_scene)

func apply_options(world: Node = null) -> void:
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus < 0:
		music_bus = AudioServer.bus_count
		AudioServer.add_bus(music_bus)
		AudioServer.set_bus_name(music_bus,"Music")
	for pair in [["Master","master"],["Music","music"]]:
		var index := AudioServer.get_bus_index(pair[0])
		var amount := clampf(float(options.get(pair[1],DEFAULTS[pair[1]])),0.0,1.0)
		AudioServer.set_bus_mute(index,amount<=0.001)
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(amount,0.001)))
	if DisplayServer.get_name()!="headless":
		var requested_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if options.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		# Re-entering WINDOWED on macOS can resize the backing viewport on each
		# settings/scene application. Only perform a real mode transition.
		if DisplayServer.window_get_mode() != requested_mode:
			DisplayServer.window_set_mode(requested_mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if options.vsync else DisplayServer.VSYNC_DISABLED)
	if world and world.has_node("Player"):
		var player: Node = world.get_node("Player")
		player.mouse_sensitivity = 0.0025*clampf(float(options.mouse),0.3,2.0)
		player.third_person_distance = clampf(float(options.camera_distance),1.25,4.0)
		player.aim_camera_distance = clampf(float(options.aim_camera_distance),0.5,2.0)
		var quality := clampi(int(options.graphics_quality),0,2)
		_apply_render_budget(world.get_viewport(), quality)
		world.get_viewport().msaa_3d = [Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X][quality]
		if world.has_node("Sun"):
			world.get_node("Sun").directional_shadow_max_distance = [40.0,80.0,130.0][quality]
		if world.has_node("WorldEnvironment"):
			var environment: Environment = world.get_node("WorldEnvironment").environment
			environment.ssao_enabled = quality > 0
			environment.ssil_enabled = quality == 2
		if world.has_node("BackgroundMusic"): world.get_node("BackgroundMusic").bus = "Music"

static func render_scale_for_size(pixels: Vector2i, quality: int) -> float:
	# Bound 3D pixel count on Retina/fullscreen displays; canvas UI stays native.
	var budget: Vector2 = [Vector2(960,540),Vector2(1280,720),Vector2(1920,1080)][clampi(quality,0,2)]
	return minf(1.0, minf(budget.x / maxf(pixels.x,1), budget.y / maxf(pixels.y,1)))

func _apply_render_budget(viewport: Viewport, quality: int) -> void:
	var pixels: Vector2i = viewport.get_texture().get_size()
	viewport.scaling_3d_scale = render_scale_for_size(pixels,quality)

func _update_render_budget() -> void:
	_apply_render_budget(get_viewport(),clampi(int(options.graphics_quality),0,2))

func _remaining_medical_ids(world: Node3D) -> Array[String]:
	var remaining: Array[String] = []
	for pickup in world.get_tree().get_nodes_in_group("medical_supplies"):
		if world.is_ancestor_of(pickup) and not pickup.is_queued_for_deletion():
			remaining.append(pickup.persistence_id())
	return remaining

func _door_states(world: Node3D) -> Dictionary:
	var states := {}
	for door in world.get_tree().get_nodes_in_group("house_doors"):
		if world.is_ancestor_of(door): states[String(world.get_path_to(door))]={"opened":door.opened,"swing_direction":door.swing_direction}
	return states

func _restore_door_states(world: Node3D,states: Dictionary) -> void:
	for path in states:
		var value = states[path]
		if not (value is bool or (value is Dictionary and value.get("opened") is bool)): continue
		var node := world.get_node_or_null(NodePath(path))
		if node != null and node.is_in_group("house_doors") and node.has_method("restore_state"):
			if value is Dictionary:
				node.swing_direction=-1.0 if float(value.get("swing_direction",1.0))<0 else 1.0
				node.restore_state(value.opened)
			else: node.restore_state(value)

func _remaining_household_ids(world: Node3D) -> Array[String]:
	var remaining: Array[String] = []
	for pickup in world.get_tree().get_nodes_in_group("household_pickups"):
		if world.is_ancestor_of(pickup) and not pickup.is_queued_for_deletion():
			remaining.append(str(pickup.get_meta("pickup_id")))
	return remaining

func restore_household_pickups(world: Node3D, data: Dictionary) -> void:
	# Old saves omit this field and retain the new placements.
	if not data.get("remaining_household_ids") is Array: return
	for pickup in world.get_tree().get_nodes_in_group("household_pickups"):
		if world.is_ancestor_of(pickup) and not str(pickup.get_meta("pickup_id")) in data.remaining_household_ids:
			pickup.queue_free()

func _cattle_states(world:Node3D)->Dictionary:
	var states:Dictionary={}
	for yard in world.get_tree().get_nodes_in_group("household_cattle"):
		if world.is_ancestor_of(yard):states[str(world.get_path_to(yard))]=yard.export_state()
	return states
func _restore_cattle_states(world:Node3D,states:Variant)->void:
	if not states is Dictionary:return
	for path in states:
		var yard:=world.get_node_or_null(NodePath(str(path)))
		if yard!=null and yard.is_in_group("household_cattle") and states[path] is Dictionary:yard.restore_state(states[path])

func _institution_states(world: Node3D) -> Dictionary:
	var states: Dictionary = {}
	for operations in world.get_tree().get_nodes_in_group("institution_operations"):
		if world.is_ancestor_of(operations): states[str(world.get_path_to(operations))] = operations.export_state()
	return states

func _administrative_service_states(world: Node3D) -> Dictionary:
	var states := {}
	for service in world.get_tree().get_nodes_in_group("administrative_services"):
		if world.is_ancestor_of(service): states[str(world.get_path_to(service))] = service.export_state()
	return states

func _restore_bindings() -> void:
	if not options.key_bindings is Dictionary: options.key_bindings = {}
	for action in options.key_bindings:
		if action == "pause" or not _original_input_events.has(action): continue
		var events: Array = _original_input_events[action].filter(func(event): return not event is InputEventKey)
		var key := InputEventKey.new()
		key.physical_keycode = int(options.key_bindings[action])
		events.append(key)
		_original_input_events[action] = events

func bind_key(action: String, keycode: int) -> bool:
	if action == "pause" or keycode in [KEY_ESCAPE,KEY_NONE] or not _original_input_events.has(action): return false
	for other in _original_input_events:
		if other == action or str(other).begins_with("ui_"): continue
		for event in _original_input_events[other]:
			if event is InputEventKey and event.physical_keycode == keycode: return false
	options.key_bindings = options.key_bindings.duplicate(true)
	options.key_bindings[action] = keycode
	_restore_bindings()
	_input_map_applied = false
	_set_active_input_device(active_input_device)
	set_option("key_bindings",options.key_bindings)
	return true
