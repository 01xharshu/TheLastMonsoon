extends Node3D
## Fictional petition dispute and assessed revenue; preserve original office services.
const Prompt = preload("res://world/suryagarh/settlements/operation_prompt.gd")
var clock: Node
var district: Node3D
var case_stage := "unfiled"
var assessment := 0
var revenue_paid := 0
var treasury_looted := false
var pending: Dictionary = {}
var claimant: CharacterBody3D

func configure(site: Node3D) -> void:
	district = site
	var world: Node = preload("res://systems/world_context.gd").find_world(site)
	if world == null:
		push_error("Civic missions require their owning world's clock")
		return
	clock = world.get_node("GameTimeSystem")
	add_to_group("institution_operations")
	station("evidence","Review disputed account",site.get_node("Collectorate"),Vector3(-1.7,.24,-1.5),site.get_node("Collectorate/PetitionClerk"))
	station("hearing","Present petition at hearing",site.get_node("BritishCourthouse"),Vector3(0,.42,-4.6),site.get_node("BritishCourthouse/PresidingOfficer"))
	station("assessment","Request revenue assessment",site.get_node("Collectorate"),Vector3(2.7,.24,-1.5),site.get_node("Collectorate/PetitionClerk"))
	station("instalment","Pay assessed revenue · up to 2 rupees",site.get_node("DistrictTreasury"),Vector3(-3,.24,3.4),site.get_node("DistrictTreasury/RevenueClerk"))
	station("key","Request strongroom inspection key",site.get_node("DistrictTreasury"),Vector3(-6,.24,3.4),site.get_node("DistrictTreasury/RevenueClerk"))
	station("tools","Buy lock tools · 4 rupees",site.get_node("Collectorate"),Vector3(-4,.24,3),null)
	station("robbery","Take treasury cash box",site.get_node("DistrictTreasury"),Vector3(0,.24,-6),null)

func station(id: String,label: String,room: Node3D,at: Vector3,staff: Node3D) -> void:
	var prompt := Prompt.new()
	prompt.name = id.capitalize()+"Mission"
	prompt.action_id = id
	prompt.interaction_text = label
	prompt.operations = self
	prompt.attendant = staff
	prompt.position = at
	prompt.marker_height = 1
	room.add_child(prompt)

func request(id: String,player: CharacterBody3D) -> bool:
	if player.health <= 0 or not pending.is_empty(): return false
	var inv: InventoryComponent = player.get_node("InventoryComponent")
	if id != "robbery" and (clock.current_hour < 9 or clock.current_hour >= 17):
		inv.message_requested.emit("Office services reopen at nine")
		return false
	match id:
		"evidence":
			if case_stage != "unfiled" or not inv.has_item("court_receipt"):
				inv.message_requested.emit("Register the petition at court first")
				return false
			case_stage = "evidence"
			inv.add_item("disputed_account",1)
			inv.message_requested.emit("The account records a double charge. Present it at court.")
		"hearing":
			if case_stage != "evidence" or not inv.has_item("disputed_account"): return false
			claimant = player
			pending = {"remaining":8.0,"start":player.global_position}
			inv.message_requested.emit("Hearing: the clerk reads the account; remain before the bench")
		"assessment":
			if assessment > 0: return false
			assessment = 6
			inv.add_item("revenue_assessment",1)
			inv.message_requested.emit("Assessed balance: 6 rupees, payable in instalments")
		"instalment":
			var amount := mini(2,assessment-revenue_paid)
			if amount <= 0 or inv.get_item_count("rupees") < amount: return false
			inv.remove_item("rupees",amount)
			revenue_paid += amount
			if revenue_paid == assessment: inv.add_item("revenue_clearance",1)
			inv.message_requested.emit("Revenue balance: %d rupees" % (assessment-revenue_paid))
		"key":
			if revenue_paid != 6 or case_stage != "resolved" or inv.has_item("treasury_key"): return false
			inv.add_item("treasury_key",1)
			inv.message_requested.emit("Inspection key issued; taking funds remains theft")
		"tools":
			if inv.has_item("lock_tools") or inv.get_item_count("rupees") < 4: return false
			inv.remove_item("rupees",4)
			inv.add_item("lock_tools",1)
		"robbery":
			var door = district.get_node("DistrictTreasury/StrongroomDoor")
			if treasury_looted or not door.opened: return false
			treasury_looted = true
			inv.add_item("rupees",20)
			get_tree().call_group("police_crime_observers","report_crime",player,"theft",player.global_position)
		_: return false
	return true

func _process(delta: float) -> void:
	if pending.is_empty(): return
	var judge = district.get_node("BritishCourthouse/PresidingOfficer")
	if not is_instance_valid(claimant) or claimant.health <= 0 or claimant.global_position.distance_to(pending.start) > 2.5 or judge.get_meta("dead",false) or judge.get_meta("knocked_out",false) or clock.current_hour >= 17:
		pending.clear()
		return
	pending.remaining -= delta
	if pending.remaining <= 0:
		var inv: InventoryComponent = claimant.get_node("InventoryComponent")
		if not inv.has_item("disputed_account"):
			pending.clear(); return
		inv.remove_item("disputed_account",1)
		inv.add_item("court_order",1)
		case_stage = "resolved"
		inv.message_requested.emit("Court order: the duplicate charge is struck from the account")
		pending.clear()

func export_state() -> Dictionary:
	return {"case_stage":case_stage,"assessment":assessment,"revenue_paid":revenue_paid,"treasury_looted":treasury_looted}

func restore_state(data: Dictionary) -> void:
	pending.clear()
	case_stage = str(data.get("case_stage","unfiled"))
	if case_stage not in ["unfiled","evidence","resolved"]: case_stage = "unfiled"
	assessment = 6 if int(data.get("assessment",0)) == 6 else 0
	revenue_paid = clampi(int(data.get("revenue_paid",0)),0,assessment)
	treasury_looted = bool(data.get("treasury_looted",false))
