extends Node
## Shoreline interaction shared by river drinking and the carried water pouch.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const ACTION_SECONDS := 1.8
var layout := Layout.new()
var action := ""
var elapsed := 0.0
@onready var actor: CharacterBody3D = get_parent()
@onready var inventory: InventoryComponent = actor.get_node("InventoryComponent")
@onready var survival: SurvivalComponent = actor.get_node("SurvivalComponent")

func can_use_river() -> bool:
	if actor.is_swimming or not actor.is_on_floor() or actor.get_meta("climbing",false): return false
	if actor.get_meta("mounted_vehicle", null) != null or actor.get_meta("river_action","")!="": return false
	var z: float = actor.global_position.z
	var river: float = layout.river_x(z)
	var x: float = actor.global_position.x
	if absf(x-river)>layout.river_width(z)+39.0 or actor.global_position.y>2.8: return false
	var direction := signf(river-x)
	for step in 21:
		var sample_x: float = x+direction*float(step)*0.2
		if absf(sample_x-river)<=layout.river_width(z)+36.0 and layout.height(sample_x,z)<=0.05:
			return true
	return false

func start_drink() -> bool:
	if not can_use_river(): return false
	if survival.hydration >= survival.max_hydration:
		inventory.request_message("You are not thirsty")
		return false
	start_action("drink")
	return true

func start_fill() -> bool:
	if not can_use_river(): return false
	if not inventory.has_water_bag():
		inventory.request_message("You need a water pouch")
		return false
	if inventory.get_available_water_capacity_liters()<=0.0:
		inventory.request_message("Water pouch is full")
		return false
	start_action("fill")
	return true

func start_action(value: String) -> void:
	action = value
	elapsed = 0.0
	actor.set_meta("river_action",value)
	actor.set_meta("river_action_progress",0.0)
	var equipment: Node3D = actor.get_node("VisualRoot/CharacterVisual").equipment
	if equipment:
		equipment.stowed = true
		equipment._refresh()
	actor.velocity = Vector3.ZERO

func _process(delta: float) -> void:
	if action.is_empty(): return
	if actor.is_swimming or not actor.is_on_floor():
		cancel()
		return
	elapsed += delta
	actor.set_meta("river_action_progress",clampf(elapsed/ACTION_SECONDS,0.0,1.0))
	if elapsed < ACTION_SECONDS: return
	if action == "drink":
		var restored: float = survival.restore_hydration(30.0)
		inventory.request_message("Drank from the river  ·  +%d water" % roundi(restored))
	else:
		var filled: float = inventory.add_water(inventory.get_available_water_capacity_liters())
		inventory.request_message("Filled water pouch  ·  %.2f L" % filled)
	cancel()

func cancel() -> void:
	action = ""
	elapsed = 0.0
	actor.remove_meta("river_action")
	actor.remove_meta("river_action_progress")
