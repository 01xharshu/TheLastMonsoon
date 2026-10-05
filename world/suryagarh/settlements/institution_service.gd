extends Interactable
## Contextual service backed by the cantonment's persistent ledger.
var operations: Node
var service_id := ""
var staff: Node3D

func _ready() -> void:
	interaction_max_distance = 2.5
	marker_height = 1.1
	interaction_text = {"hospital":"Request wound treatment · 2 rupees", "issue":"Collect daily ration", "fodder":"Collect stable fodder", "feed":"Feed stable horse", "water":"Water stable horse", "groom":"Groom stable horse", "bell":"Ring chapel bell", "worship":"Attend chapel service"}.get(service_id,"Ask about duties")
	interaction_icon = "medicine" if service_id == "hospital" else "hand"
	# No generic reaching pose is presented as a finished role-specific action.

func interaction_available() -> bool:
	return super.interaction_available() and is_instance_valid(operations) and is_instance_valid(staff) and not staff.get_meta("dead",false) and not staff.get_meta("knocked_out",false)

func interact(player: CharacterBody3D) -> void:
	if not interaction_available() or player.global_position.distance_to(global_position) > interaction_max_distance: return
	operations.request(service_id,player)
