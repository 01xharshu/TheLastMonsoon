extends Interactable
var sequence: Node
var action_id := ""
func _ready() -> void:
	collision_layer=0;set_collision_layer_value(8,true)
	var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new()
	shape.size=Vector3(.55,1.1,.55);collider.shape=shape;add_child(collider)
func interaction_available() -> bool:
	return super.interaction_available() and is_instance_valid(sequence) and sequence.can_request(action_id)
func interact(player: CharacterBody3D) -> void:
	if interaction_available() and player.global_position.distance_to(global_position)<=interaction_max_distance:
		sequence.request(action_id,player)
