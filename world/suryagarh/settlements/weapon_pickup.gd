extends Interactable
var weapon_id := "talwar"
var taken := false
func _ready() -> void:
	interaction_text = "Take and equip " + {"enfield":"Enfield rifle","talwar":"talwar","bow":"bow and quiver","pistol":"Adams pistol","double_gun":"double-barrel gun"}.get(weapon_id,weapon_id)
	hold_duration = .9
	add_to_group("weapon_pickups")
func interact(actor: CharacterBody3D) -> void:
	if taken or actor.global_position.distance_to(global_position)>3.0: return
	if (actor.get_meta("mounted_vehicle") if actor.has_meta("mounted_vehicle") else null)!=null or actor.get_meta("climbing",false): return
	if actor.inventory.has_item(weapon_id):
		actor.inventory.message_requested.emit("Already carrying " + weapon_id.capitalize())
		return
	if not actor.inventory.add_item(weapon_id,1): return
	if weapon_id == "bow": actor.inventory.add_item("arrow",12)
	if weapon_id == "pistol": actor.inventory.add_item("pistol_ball",15)
	if weapon_id == "double_gun": actor.inventory.add_item("shot_charge",8)
	taken = true
	var gear: Node = actor.get_node("VisualRoot/CharacterVisual").equipment
	gear.select_weapon({"talwar":0,"enfield":1,"bow":2,"pistol":3,"double_gun":5}[weapon_id])
	gear.stowed = false
	gear._refresh()
	actor.set_meta("stolen_weapons",int(actor.get_meta("stolen_weapons",0))+1)
	actor.inventory.message_requested.emit("Taken from the armoury · " + weapon_id.capitalize())
	queue_free()
