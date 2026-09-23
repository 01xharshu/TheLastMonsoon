extends Node
## Versioned local saves and persistent settings. No generated world data is saved.
const WORLD := "res://world/suryagarh/suryagarh_world.tscn"
const SAVE_DIR := "user://saves"
const SETTINGS_FILE := "user://settings.cfg"
const SLOT_COUNT := 3
const VERSION := 1
const DEFAULTS := {
	"master": 0.8, "music": 0.55, "mouse": 1.0,
	"fullscreen": false, "vsync": true,
}
var options: Dictionary = DEFAULTS.duplicate()
var pending_slot := -1
var save_root := SAVE_DIR
var settings_path := SETTINGS_FILE

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	load_options()
	apply_options()

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
		"water_liters": inventory.stored_water_liters,
		"survival": {
			"hydration":survival.hydration,"satiety":survival.satiety,
			"energy":survival.energy,"warmth":survival.warmth,"stamina":survival.stamina,
		},
		"weapon": {"selected":int(equipment.selected),"stowed":equipment.stowed,
			"pistol_rounds":actor.get_node("PistolCombat").rounds},
		"remaining_weapon_pickups": _remaining_weapon_pickup_ids(world),
	}
	var map: Control = actor.get_node("UI/WorldMap")
	if is_finite(map.waypoint.x): data["waypoint"] = [map.waypoint.x,map.waypoint.y]
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
		pending_slot = -1
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
	inventory.items = data.get("items",{}).duplicate(true)
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
	equipment.selected = clampi(int(weapon.get("selected",0)),0,3)
	equipment.stowed = bool(weapon.get("stowed",true))
	equipment._refresh()
	actor.get_node("PistolCombat").rounds = clampi(int(weapon.get("pistol_rounds",5)),0,5)
	if data.has("remaining_weapon_pickups"):
		var remaining: Array = data.remaining_weapon_pickups
		for pickup in world.get_tree().get_nodes_in_group("weapon_pickups"):
			if not String(pickup.get_path()) in remaining:
				pickup.queue_free()
	var map: Control = actor.get_node("UI/WorldMap")
	if data.get("waypoint") is Array and data.waypoint.size()==2:
		map.waypoint = Vector2(float(data.waypoint[0]),float(data.waypoint[1]))

func _remaining_weapon_pickup_ids(world: Node3D) -> Array[String]:
	var remaining: Array[String] = []
	for pickup in world.get_tree().get_nodes_in_group("weapon_pickups"):
		if is_instance_valid(pickup) and not pickup.is_queued_for_deletion():
			remaining.append(String(pickup.get_path()))
	return remaining

func load_options() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path)!=OK: return
	for key in DEFAULTS:
		options[key] = config.get_value("settings",key,DEFAULTS[key])

func set_option(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key): return
	options[key] = value
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
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if options.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if options.vsync else DisplayServer.VSYNC_DISABLED)
	if world and world.has_node("Player"):
		world.get_node("Player").mouse_sensitivity = 0.0025*clampf(float(options.mouse),0.3,2.0)
		if world.has_node("BackgroundMusic"): world.get_node("BackgroundMusic").bus = "Music"
