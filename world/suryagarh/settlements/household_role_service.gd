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
 var vitality:=person.get_node_or_null("Vitality")
 if vitality!=null and vitality.has_signal("died"):vitality.died.connect(_person_died)
 refresh_physics()
func interaction_available() -> bool:
 var available:=super.interaction_available() and is_instance_valid(person)
 if available:
  available=not person.get_meta("dead",false) and not person.get_meta("knocked_out",false)
  var action:String=person.get_meta("household_action","home")
  available=available and action in ["home","work"] and person.get_meta("combat_action","")==""
 var layer:int=(1<<29) if available else 0
 if collision_layer!=layer:collision_layer=layer
 return available
func refresh_physics() -> void:interaction_available()
func _person_died() -> void:collision_layer=0
func interact(player:CharacterBody3D) -> void:
 if interaction_available() and player.global_position.distance_to(global_position)<=interaction_max_distance:ledger.request(self,player)
func secondary_interact(player:CharacterBody3D) -> void:
 if not interaction_available() or player.global_position.distance_to(global_position)>interaction_max_distance:return
 if role=="cook":ledger.supply(self,player,1,false)
 else:ledger.explain(self,player)
