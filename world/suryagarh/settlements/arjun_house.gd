extends RefCounted
## Arjun and Dev's modest home, within an existing surveyed village footprint.
func furnish(b, home: Node3D) -> void:
	home.add_to_group("arjun_home")
	home.set_meta("residents", ["Arjun", "Dev"])
	home.set_meta("story", "Dev raised Arjun after their parents died early; Dev serves as a sepoy.")
	for node in home.get_children():
		if str(node.name).begins_with("Sleeping") or str(node.name) in ["CookingHearth","HearthOpening","CookingPot","StorageChest","ChestLid"]: node.free()
	var lime: Material = b.material(Color(0.73,0.68,0.55))
	var earth: Material = b.material(Color(0.40,0.31,0.21))
	var cloth: Material = b.material(Color(0.34,0.30,0.22))
	# A sleeping alcove and cooking/storage room share a 1.5 m internal opening.
	b.piece(home,"AlcovePartitionRear",Vector3(0,1.44,-2.55),Vector3(0.18,2.4,1.8),lime)
	b.piece(home,"AlcovePartitionFront",Vector3(0,1.44,1.25),Vector3(0.18,2.4,2.7),lime)
	b.piece(home,"AlcoveLintel",Vector3(0,2.64,-0.75),Vector3(0.18,0.4,1.5),b.wood)
	# Dev's bedding is rolled during the day, leaving the central aisle open.
	b.piece(home,"DevBeddingMat",Vector3(2.5,0.255,-1.45),Vector3(1.55,0.025,2.2),cloth,false)
	b.piece(home,"RolledQuilt",Vector3(2.5,0.39,-2.35),Vector3(1.35,0.24,0.36),cloth,false)
	b.piece(home,"StorageChest",Vector3(3.65,0.52,1.15),Vector3(1.15,0.56,0.68),b.wood)
	b.piece(home,"ChestLid",Vector3(3.65,0.84,1.15),Vector3(1.2,0.08,0.72),b.wood,false)
	b.piece(home,"ChestLatch",Vector3(3.65,0.70,1.51),Vector3(0.09,0.20,0.04),b.iron,false)
	for x in [3.2,4.1]:
		b.piece(home,"ChestIronBand",Vector3(x,0.85,1.15),Vector3(0.05,0.025,0.74),b.iron,false)
	b.piece(home,"CookingHearth",Vector3(3.65,0.43,-2.65),Vector3(1.1,0.38,0.8),b.brick)
	b.piece(home,"HearthAsh",Vector3(3.65,0.63,-2.65),Vector3(0.45,0.02,0.34),b.iron,false)
	b.piece(home,"KitchenShelf",Vector3(4.32,1.45,-1.1),Vector3(0.5,0.10,1.5),b.wood,false)
	for scene_path in ["res://assets/props/polyhaven/brass_pot_01/brass_pot_01_1k.gltf","res://assets/props/polyhaven/wicker_basket_01/wicker_basket_01_1k.gltf"]:
		var prop: Node3D = load(scene_path).instantiate()
		home.add_child(prop)
		prop.position = Vector3(3.7,0.24,-0.8 if "pot" in scene_path else 0.0)
	b.piece(home,"WallPegRail",Vector3(-3.0,1.65,-3.35),Vector3(1.2,0.12,0.08),b.wood,false)
	for x in [-3.45,-3.0,-2.55]:
		b.piece(home,"TimberPeg",Vector3(x,1.65,-3.22),Vector3(0.06,0.06,0.24),b.wood,false)
	b.piece(home,"FoldedBlueCloth",Vector3(-3,1.38,-3.20),Vector3(0.45,0.50,0.06),b.material(Color(0.18,0.23,0.27)),false)
	# Courtyard gate and compacted earth approach meet the existing south lane.
	b.piece(home,"FrontCourtyard",Vector3(0,0.025,6.35),Vector3(9.0,0.05,5.0),earth,false)
	for side in [-1.0,1.0]:
		b.piece(home,"CourtyardLowWall",Vector3(side*4.5,0.47,6.5),Vector3(0.23,0.94,5.4),b.ochre)
		b.piece(home,"CourtyardGateWall",Vector3(side*2.9,0.47,9.1),Vector3(3.2,0.94,0.23),b.ochre)
	b.piece(home,"HomeToSouthLane",Vector3(0,0.018,16.7),Vector3(2.4,0.035,15.2),earth,false)
	# Keep a stable world-root Charpai so existing interaction/save references survive.
	var bed: Node3D = b.get_parent().get_node("Charpai")
	bed.global_transform = home.global_transform * Transform3D(Basis.IDENTITY,Vector3(-2.35,0.24,-1.4))
	bed.set_meta("home", "Arjun and Dev")
