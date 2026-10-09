extends Node3D
## Military dispatch, player-driven supply convoy and controlled road crossing.
const Prompt = preload("res://world/suryagarh/settlements/operation_prompt.gd")
const Door = preload("res://objects/hinged_door.gd")
var mail_stage := "available"
var convoy_stage := "available"
var paid_days: Dictionary = {}
var world: Node3D
var gate: Interactable
var clock: Node

func configure(scene: Node3D) -> void:
	world = scene
	clock = world.get_node("GameTimeSystem")
	add_to_group("institution_operations")
	var depot := world.get_node("Settlement/BritishCantonment/MilitarySupplyDepot")
	station("mail_pickup","Accept sealed military mail",depot,Vector3(0,.24,2))
	station("convoy_pickup","Load supply consignment · driver cart required",depot,Vector3(-2,.24,2))
	station("mail_deliver","Deliver sealed military mail",world.get_node("Settlement/AdministrativeDistrict/Collectorate"),Vector3(3,.24,3))
	station("convoy_deliver","Unload military consignment · driver cart required",world.get_node("Settlement/AdministrativeDistrict/DistrictTreasury"),Vector3(0,.24,7))
	if world.has_node("TimberBridge"):
		var bridge: Node3D = world.get_node("TimberBridge")
		gate = Door.new()
		gate.name = "RevenueCrossingGate"
		gate.width = bridge.WIDTH + 2.0
		gate.height = 1.25
		gate.opened = false
		gate.locked = true
		gate.night_lock = false
		gate.auto_open_at_dawn = false
		gate.rotation.y = PI/2
		gate.position = bridge.ramp_point(-1,1)+Vector3(0,.03,0)
		bridge.add_child(gate)
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(.25,.15,.075)
		gate.build(wood)
		# build() resets yaw and adds half-width to local X. Centre the gate on the road.
		gate.position = bridge.ramp_point(-1,1)+Vector3(0,.03,0)
		gate.rotation.y = PI/2
		station("crossing","Pay crossing toll · 1 rupee",bridge,bridge.ramp_point(-1,1)+Vector3(-2,.1,bridge.WIDTH*.5+2.0))

func station(id: String,label: String,parent: Node3D,at: Vector3) -> void:
	var prompt := Prompt.new()
	prompt.name = id.capitalize()+"Dispatch"
	prompt.position = at
	prompt.action_id = id
	prompt.operations = self
	prompt.interaction_text = label
	prompt.marker_height = 1
	parent.add_child(prompt)

func cart_near(player: CharacterBody3D,target: Vector3) -> bool:
	for cart in get_tree().get_nodes_in_group("cart_parking_vehicles"):
		if not cart.has_method("can_move") or not cart.can_move(): continue
		if cart.boarding.rider == player and cart.boarding.role == "driver" and cart.global_position.distance_to(target) < 14 and absf(cart.boarding.speed) < .3:
			return true
	return false

func request(id: String,player: CharacterBody3D) -> bool:
	if player.health <= 0: return false
	var inv: InventoryComponent = player.get_node("InventoryComponent")
	match id:
		"mail_pickup":
			if mail_stage != "available": return false
			mail_stage = "carrying"
			inv.add_item("military_mail",1)
			inv.message_requested.emit("Deliver the sealed mail to the Collectorate dispatch desk")
		"mail_deliver":
			if mail_stage != "carrying" or not inv.has_item("military_mail"): return false
			inv.remove_item("military_mail",1)
			mail_stage = "delivered"
			inv.add_item("rupees",6)
		"convoy_pickup":
			if convoy_stage != "available": return false
			var depot: Node3D = world.get_node("Settlement/BritishCantonment/MilitarySupplyDepot")
			if not cart_near(player,depot.get_node("Entrance").global_position):
				inv.message_requested.emit("Stop a cart outside the depot while driving it")
				return false
			convoy_stage = "carrying"
			inv.add_item("military_consignment",1)
			inv.message_requested.emit("Drive the consignment to the Treasury's receiving entrance")
		"convoy_deliver":
			if convoy_stage != "carrying" or not inv.has_item("military_consignment"): return false
			var treasury: Node3D = world.get_node("Settlement/AdministrativeDistrict/DistrictTreasury")
			if not cart_near(player,treasury.get_node("Entrance").global_position): return false
			inv.remove_item("military_consignment",1)
			convoy_stage = "delivered"
			inv.add_item("rupees",12)
		"crossing":
			if not is_instance_valid(gate): return false
			if not paid_days.has(str(clock.current_day)):
				if inv.get_item_count("rupees") < 1: return false
				inv.remove_item("rupees",1)
				paid_days[str(clock.current_day)] = true
			gate.locked = false
			gate.set_open(true)
		_: return false
	return true

func export_state() -> Dictionary:
	return {"mail_stage":mail_stage,"convoy_stage":convoy_stage,"paid_days":paid_days.duplicate(true)}

func restore_state(data: Dictionary) -> void:
	mail_stage = str(data.get("mail_stage","available"))
	convoy_stage = str(data.get("convoy_stage","available"))
	if mail_stage not in ["available","carrying","delivered"]: mail_stage = "available"
	if convoy_stage not in ["available","carrying","delivered"]: convoy_stage = "available"
	paid_days = data.get("paid_days",{}).duplicate() if data.get("paid_days",{}) is Dictionary else {}
	if is_instance_valid(gate): gate.locked = not paid_days.has(str(clock.current_day))
