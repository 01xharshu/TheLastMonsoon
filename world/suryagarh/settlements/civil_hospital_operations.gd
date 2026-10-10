extends "res://world/suryagarh/settlements/cantonment_operations.gd"
## Civilian ward reuses treatment/cancellation rules, with an independent saved ledger.
func configure(site:Node3D) -> void:
	district=site
	add_to_group("institution_operations")
	clock=site.get_parent().get_parent().get_node("GameTimeSystem")
	stock_day=clock.current_day
	clock.time_changed.connect(_time_changed)

func request(id:String,actor:CharacterBody3D) -> bool:
	if id!="hospital":return false
	return super.request(id,actor)

func export_state() -> Dictionary:
	return {"ledger":ledger.duplicate(true),"stock":stock.duplicate(true),"stock_day":stock_day}

func restore_state(data:Dictionary) -> void:
	cancel();ledger.clear()
	var saved:Variant=data.get("ledger",{})
	if saved is Dictionary:
		for key in saved:
			if saved[key]==true:ledger[str(key)]=true
	stock_day=maxi(1,int(data.get("stock_day",clock.current_day)))
	var supplies:Variant=data.get("stock",{})
	if supplies is Dictionary:stock.dressings=clampi(int(supplies.get("dressings",8)),0,16)
