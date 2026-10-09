extends Interactable
var team:Node
func _ready()->void:
	interaction_text="Hitch or unhitch team";hold_duration=1;collision_layer=1;collision_mask=0
func interact(actor:CharacterBody3D)->void:
	if not interaction_available() or actor.global_position.distance_to(global_position)>3:return
	team.use(actor)
