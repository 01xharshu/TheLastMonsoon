extends Interactable
## A contextual conversation, board, collection or work point.
var manager: Node
var endpoint := ""
var person: Node3D

func _ready() -> void:
	marker_height = .2 if person != null else .3
	interaction_text = "Talk about work" if person != null else "Read work notices"
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.72, 1.6, .72) if person != null else Vector3(.65,.65,.4)
	collider.shape = shape
	collider.position.y = -.1 if person != null else 0.0
	add_child(collider)
	collision_layer = 1 << 29 # Conversation ray; the person's separate body remains solid.
	collision_mask = 0

func interaction_available() -> bool:
	return super.interaction_available() and (person == null or not person.get_meta("dead", false))

func interact(actor: CharacterBody3D) -> void:
	if not interaction_available() or actor.global_position.distance_to(global_position) > interaction_max_distance: return
	manager.use_endpoint(endpoint, actor)
