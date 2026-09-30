extends RefCounted
## Fictional fortified district command residence on the existing surveyed estate.
func build(b) -> void:
	b.add_to_group("occupied_command_fort")
	b.set_meta("story_role","British district commander residence and rule-making court")
	for x in [-88.0,88.0]:
		for z in [-84.0,84.0]:
			b.box("FortCornerBastion",Vector3(x,3.1,z),Vector3(14,6.2,14),b.brick)
			b.box("BastionCoping",Vector3(x,6.3,z),Vector3(14.5,.25,14.5),b.stone)
			for offset in [-5.0,-2.5,0.0,2.5,5.0]:
				for edge in [-1.0,1.0]:
					b.box("BastionMerlon",Vector3(x+offset,6.9,z+edge*6.4),Vector3(1.4,1.2,1.1),b.brick)
					b.box("BastionMerlon",Vector3(x+edge*6.4,6.9,z+offset),Vector3(1.1,1.2,1.4),b.brick)
	b.box("ServiceCourtFloor",Vector3(0,.09,-72),Vector3(130,.18,25),b.stone)
	b.box("CommandNoticeBoard",Vector3(8,1.5,3),Vector3(2.4,1.8,.14),b.wood)
	for x in [7.0,9.0]: b.box("NoticeBoardPost",Vector3(x,.75,3),Vector3(.14,1.5,.14),b.wood)
	for row in 3: b.box("PostedDistrictOrder",Vector3(8,1.95-row*.5,3.08),Vector3(1.9,.36,.015),b.plaster,false)
	b.box("ServiceCourtWalk",Vector3(-69,.09,-40),Vector3(4,.18,70),b.stone)
	for i in 3:
		var room := Node3D.new()
		room.name = ["FortKitchen","FortStores","ServantQuarters"][i]
		room.position = Vector3(-45+i*45,.18,-73)
		b.add_child(room)
		b.piece(room,"Floor",Vector3(0,.12,0),Vector3(18,.24,14),b.stone)
		b.piece(room,"RearWall",Vector3(0,1.8,-7),Vector3(18,3.6,.4),b.plaster)
		for side in [-1.0,1.0]:
			b.piece(room,"SideWall",Vector3(side*9,1.8,0),Vector3(.4,3.6,14),b.plaster)
			b.piece(room,"FrontPier",Vector3(side*5.15,1.8,7),Vector3(7.7,3.6,.4),b.plaster)
		b.piece(room,"DoorHeader",Vector3(0,3.0,7),Vector3(2.6,1.2,.4),b.plaster)
		b.piece(room,"Roof",Vector3(0,3.7,0),Vector3(19,.22,15),b.tile)
		var door := preload("res://objects/hinged_door.gd").new()
		door.name = "ServiceDoor"
		door.position = Vector3(-1.3,.24,7.22)
		door.night_lock = false
		door.build(b.wood)
		room.add_child(door)
		if i == 0:
			b.piece(room,"CookingHearth",Vector3(-6,.5,-4),Vector3(3,1,1.8),b.brick)
			b.piece(room,"PreparationTable",Vector3(4,.9,-3),Vector3(4,.18,1.2),b.wood)
			for x in [2.5,5.5]:
				for z in [-3.4,-2.6]: b.piece(room,"TableLeg",Vector3(x,.45,z),Vector3(.12,.9,.12),b.wood)
		elif i == 1:
			for x in [-6.0,-3.0,3.0,6.0]:
				b.piece(room,"ProvisionChest",Vector3(x,.65,-4),Vector3(2,1.3,1.6),b.wood)
				b.piece(room,"ChestIronBand",Vector3(x,.65,-3.18),Vector3(.15,1.3,.04),b.iron,false)
		else:
			for x in [-5.0,0.0,5.0]:
				b.piece(room,"StaffBed",Vector3(x,.45,-3),Vector3(2,.3,3.5),b.wood)
				b.piece(room,"StaffBedding",Vector3(x,.65,-3),Vector3(1.8,.1,3.3),b.plaster,false)
				for side in [-.7,.7]:
					for z in [-4.3,-1.7]: b.piece(room,"BedLeg",Vector3(x+side,.2,z),Vector3(.12,.4,.12),b.wood)

func staff(b) -> void:
	for i in 2:
		var actor := preload("res://characters/npcs/households/household_npc_actor.gd").new()
		actor.name = "FortCook" if i == 0 else "FortSteward"
		actor.household_job = "Cook" if i == 0 else "Steward"
		actor.movement_enabled = false
		actor.position = Vector3(-41,.42,-74) if i == 0 else Vector3(0,.42,-65)
		actor.set_meta("visual_status","candidate_unapproved")
		actor.add_child(load("res://characters/npcs/village_farmer.glb").instantiate())
		b.add_child(actor)
