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
	if world.has_node("TimberBridge"):build_inspection_post(world.get_node("TimberBridge"))

func build_inspection_post(bridge: Node3D) -> void:
	var booth:=Node3D.new();booth.name="BridgeInspectionPost";bridge.add_child(booth)
	booth.position=bridge.ramp_point(-1,1)+Vector3(0,0,bridge.WIDTH*.5+3.5)
	var builder:=preload("res://world/suryagarh/settlements/settlement_builder.gd").new()
	var wood:=builder.material(Color(.27,.16,.09));var plaster:=builder.material(Color(.69,.61,.47))
	builder.piece(booth,"Floor",Vector3(0,.1,0),Vector3(3.4,.2,3.2),wood)
	builder.piece(booth,"BackWall",Vector3(0,1.3,1.5),Vector3(3.4,2.6,.2),plaster)
	for x in [-1.6,1.6]:
		builder.piece(booth,"SideWall",Vector3(x,1.3,0),Vector3(.2,2.6,3.2),plaster)
		builder.piece(booth,"FrontPost",Vector3(x,1.3,-1.5),Vector3(.15,2.6,.15),wood)
	builder.piece(booth,"Roof",Vector3(0,2.7,0),Vector3(3.8,.18,3.6),wood)
	builder.piece(booth,"InspectionDesk",Vector3(0,.75,-.65),Vector3(1.7,.12,.75),wood)
	for x in [-.7,.7]:builder.piece(booth,"DeskLeg",Vector3(x,.35,-.65),Vector3(.12,.7,.6),wood)
	builder.piece(booth,"OfficerBench",Vector3(0,.55,.6),Vector3(.75,.12,.6),wood)
	for x in [-.27,.27]:builder.piece(booth,"BenchLeg",Vector3(x,.25,.6),Vector3(.10,.5,.55),wood)
	var officer:=preload("res://characters/npcs/households/household_npc_actor.gd").new()
	officer.name="BridgeInspectionOfficer";officer.movement_enabled=false;officer.rotation.y=PI
	officer.set_meta("combat_faction","police");officer.set_meta("assigned_workplace",str(booth.get_path()))
	officer.add_child(preload("res://characters/npcs/thana/daroga_motion.glb").instantiate());booth.add_child(officer)
	officer.position=Vector3(0,.1,.6)
	var sitting:=preload("res://story/community_social.gd").new();officer.add_child(sitting)
	sitting.person=officer;sitting.seated=true;sitting.ground_y=officer.global_position.y
	builder.free()

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
			# Legacy interactions/saves cannot reinstate the removed road barrier.
			inv.message_requested.emit("The bridge crossing is open.")
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
