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
					if not (edge == -signf(z) and offset == 0):
						b.box("BastionMerlon",Vector3(x+offset,6.9,z+edge*6.4),Vector3(1.4,1.2,1.1),b.brick)
					b.box("BastionMerlon",Vector3(x+edge*6.4,6.9,z+offset),Vector3(1.1,1.2,1.4),b.brick)
	# Solid masonry stair flights give each bastion a real route from the court.
	for x in [-88.0,88.0]:
		for direction in [-1.0,1.0]:
			var route: Array[Vector3] = [Vector3(x,.18,direction*59.5)]
			for step in 32:
				var rise := .18+6.24*float(step+1)/32.0
				b.box("BastionStair",Vector3(x,rise*.5,direction*(61.25+step*.5)),Vector3(2.8,rise,.53),b.stone)
			for step in [0,8,16,24,31]: route.append(Vector3(x,.18+6.24*float(step+1)/32.0,direction*(61.25+step*.5)))
			route.append(Vector3(x,6.425,direction*80.0))
			b.set_meta("bastion_route_%d_%d"%[int(x+88),int(direction+1)],route)
			for edge in [-1.0,1.0]:
				for post in 9:
					var t := float(post)/8.0
					b.box("BastionStairRailPost",Vector3(x+edge*1.43,.18+6.24*t+.48,direction*(61+16*t)),Vector3(.07,.96,.07),b.iron,false)
				var rail: Node3D = b.box("BastionStairHandrail",Vector3(x+edge*1.43,4.25,direction*69),Vector3(.065,.065,sqrt(16*16+6.24*6.24)),b.iron,false)
				rail.rotation.x=-direction*atan2(6.24,16.0)
			b.box("BastionEntryLanding",Vector3(x,6.32,direction*77.0),Vector3(2.8,.20,1.2),b.stone)
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
		var details := preload("res://world/suryagarh/settlements/fort_service_detail.gd").new()
		details.configure()
		details.shell(b,room)
		var door := preload("res://objects/hinged_door.gd").new()
		door.name = "ServiceDoor"
		door.position = Vector3(-1.3,.24,7.22)
		door.night_lock = false
		door.build(b.wood)
		room.add_child(door)
		details.furnish(b,room,i)
	var main_details := preload("res://world/suryagarh/settlements/fort_service_detail.gd").new()
	main_details.configure()
	main_details.command_rooms(b)

func staff(b) -> void:
	for i in 2:
		var actor := preload("res://characters/npcs/households/fort_staff.gd").new()
		actor.name = "FortCook" if i == 0 else "FortSteward"
		actor.household_job = "Cook" if i == 0 else "Steward"
		actor.movement_enabled = false
		actor.position = Vector3(-41,.42,-75.05) if i == 0 else Vector3(0,.18,-65)
		actor.rotation.y = PI if i == 0 else 0.0
		actor.set_meta("visual_status","candidate_unapproved")
		actor.add_to_group("fort_staff")
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var path := "res://WorkingAssets/NPCs/village_farmer/village_farmer_rigged_candidate.glb"
		if document.append_from_file(ProjectSettings.globalize_path(path),state) != OK:
			push_error("Cannot load fort staff rig: "+path)
			continue
		actor.add_child(document.generate_scene(state))
		b.add_child(actor)
