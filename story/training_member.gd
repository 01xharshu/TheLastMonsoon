extends "res://characters/npcs/households/household_npc_actor.gd"
func _ready() -> void:
 movement_enabled=false;set_meta("combat_faction","training");set_meta("training_partner",true)
 super._ready()
 var vitality: Node=get_node("Vitality")
 var values: Dictionary={}
 for field in ["actor","skeleton","spine_bone","pelvis_bone","neck_bone","head_bone","torso_shape","head_shape","hit_body"]:values[field]=vitality.get(field)
 vitality.set_script(preload("res://story/training_vitality.gd"))
 for field in values:vitality.set(field,values[field])
