extends Interactable
## One reachable handle or driver's step, attached to a cart candidate.
var cart: Node3D
var seat_name := ""
var role := "passenger"

func configure(owner_cart: Node3D, seat: String, kind: String) -> void:
	cart = owner_cart
	seat_name = seat
	role = kind
	interaction_text = "Drive cart" if role == "driver" else "Ride as passenger"
	interaction_icon = "gate" if role == "passenger" else "hand"
	hold_duration = .55
	marker_height = 0.0

func interaction_available() -> bool:
	if not super.interaction_available() or not is_instance_valid(cart) or cart.rider != null: return false
	if role == "passenger" and absf(position.x) > .8:
		var camera := get_viewport().get_camera_3d()
		if camera != null and signf(cart.to_local(camera.global_position).x) != signf(position.x): return false
	return true

func interact(player: CharacterBody3D) -> void:
	if is_instance_valid(cart): cart.board_at(player, seat_name, role)
