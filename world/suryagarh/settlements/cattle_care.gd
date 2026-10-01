extends Interactable
var yard: Node3D
var action := "fodder"
func _ready() -> void:
	interaction_text="Put household fodder in manger" if action=="fodder" else "Pour pouch water into cattle trough"
	interaction_icon="food" if action=="fodder" else "water"
	hold_duration=1.2;interaction_max_distance=2.0;interaction_pose="low_reach"
func interact(player: CharacterBody3D) -> void:
	if player.global_position.distance_to(global_position)>interaction_max_distance+.25:return
	var inventory: Node=player.get_node_or_null("InventoryComponent")
	if inventory==null:return
	if action=="fodder":
		if yard.fodder_stock<=0:
			inventory.request_message("The household fodder basket is empty");return
		if yard.feed_portions>=3:
			inventory.request_message("The manger has enough fodder");return
		yard.fodder_stock-=1;yard.feed_portions+=1
		inventory.request_message("Fodder set out for the north-lane household's cow")
	else:
		var amount:float=minf(2.0,8.0-yard.water_liters)
		if amount<=0:
			inventory.request_message("The cattle trough is full");return
		amount=minf(amount,inventory.get_stored_water_liters())
		if amount<=0:
			inventory.request_message("Fill your water pouch first");return
		yard.water_liters+=inventory.consume_water(amount)
		inventory.request_message("Water poured into the household's cattle trough")
	yard.refresh_supplies()
