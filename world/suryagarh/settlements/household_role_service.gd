extends Interactable
var ledger:Node
var person:Node3D
var role_id:=""
var role:=""
var home_id:=""
func _ready() -> void:
 add_to_group("household_role_services")
 interaction_max_distance=2.6;marker_height=.2
 interaction_text={"landowner":"Ask about estate work","merchant":"Sell one mango · 2 rupees","official":"Show revenue paperwork","host":"Supply pantry · 2 roti","cook":"Buy kitchen roti · 2 rupees","water":"Fill water bag","coachman":"Ask about coach route"}.get(role,"Talk")
 secondary_interaction_text="Supply kitchen · 1 roti" if role=="cook" else "Ask about duties"
 var collider:=CollisionShape3D.new();var shape:=SphereShape3D.new();shape.radius=.18;collider.shape=shape;add_child(collider)
 collision_layer=1<<29;collision_mask=0;position=Vector3(0,1.2,.55)
func interaction_available() -> bool:
 if not super.interaction_available() or not is_instance_valid(person):return false
 if person.get_meta("dead",false) or person.get_meta("knocked_out",false):return false
 var action:String=person.get_meta("household_action","home")
 return action in ["home","work"] and person.get_meta("combat_action","")==""
func interact(player:CharacterBody3D) -> void:
 if interaction_available() and player.global_position.distance_to(global_position)<=interaction_max_distance:ledger.request(self,player)
func secondary_interact(player:CharacterBody3D) -> void:
 if not interaction_available() or player.global_position.distance_to(global_position)>interaction_max_distance:return
 if role=="cook":ledger.supply(self,player,1,false)
 else:ledger.explain(self,player)
