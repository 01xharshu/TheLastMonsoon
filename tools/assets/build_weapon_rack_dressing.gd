extends "res://tools/assets/build_craft_batch.gd"
func build() -> void:
	var rack := Node3D.new()
	rack.name = "WeaponRackDressing"
	var wood := material(Color(.25,.16,.08))
	var iron := material(Color(.13,.14,.13))
	iron.metallic = .65
	var lining := material(Color(.31,.28,.20))
	for y in [1.10,1.765]:
		box(rack,"ShelfLining",Vector3(4.5,.008,.83),Vector3(0,y+.004,0),lining)
		for x in [-2.20,2.20]:
			box(rack,"RetainingCleat",Vector3(.07,.05,.85),Vector3(x,y+.025,0),wood)
	for x in [-2.34,2.34]:
		for y in [.52,1.55]:
			box(rack,"IronStrap",Vector3(.125,.09,.018),Vector3(x,y,.505),iron)
			for offset in [-.03,.03]:
				rod(rack,"Fastener",Vector3(x+offset,y,.51),Vector3(x+offset,y,.524),.008,iron)
	for x in [-1.7,0,1.7]:
		box(rack,"BackBoardSeam",Vector3(.008,1.55,.01),Vector3(x,1.05,-.413),iron)
	marker(rack,"LowerShelfReach",Vector3(0,1.10,.55))
	marker(rack,"UpperShelfReach",Vector3(0,1.765,.55))
	pack_set(rack,"weapon_rack_dressing")
	print("RACK: lining, cleats, straps and reference markers built")
	quit()
