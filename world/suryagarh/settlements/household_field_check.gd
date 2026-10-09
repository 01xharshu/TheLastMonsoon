extends Interactable
var ledger:Node
var index:=0
func _ready() -> void:
 interaction_text="Check estate field boundary %d/3"%(index+1);hold_duration=2.0;marker_height=.25
 interaction_max_distance=2.5;collision_layer=1<<29;collision_mask=0
 var collider:=CollisionShape3D.new();var shape:=SphereShape3D.new();shape.radius=.18;collider.shape=shape;add_child(collider)
func interaction_available() -> bool:
 return super.interaction_available() and ledger.survey_active and not index in ledger.survey_checked
func interact(player:CharacterBody3D) -> void:
 if interaction_available() and player==ledger.player and player.global_position.distance_to(global_position)<=interaction_max_distance:
  ledger.survey_checked.append(index);ledger.mark_survey();ledger.message("Field checked: %d of 3. Return to the landowner after all three."%ledger.survey_checked.size())
