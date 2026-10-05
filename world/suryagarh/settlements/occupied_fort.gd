extends RefCounted
## Fictional fortified district command residence on the existing surveyed estate.
func build(b) -> void:
	b.brick = preload("res://world/suryagarh/settlements/military_detail.gd").surface(Color(.42,.27,.20),1)
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
	var armoury := Node3D.new()
	armoury.name = "FortArmoury"
	armoury.position = Vector3(69,.18,-40)
	b.add_child(armoury)
	armoury.add_to_group("fort_armoury")
	var armoury_details := preload("res://world/suryagarh/settlements/fort_service_detail.gd").new()
	armoury_details.configure()
	armoury_details.shell(b,armoury)
	preload("res://world/suryagarh/settlements/ammunition_display.gd").furnish(b,armoury,Vector3(0,0,-4),"fort_armoury/ammunition")
	for x in [-6.0,6.0]:
		b.piece(armoury,"WeaponRackBase",Vector3(x,.5,-4),Vector3(2.8,.18,.8),b.wood)
		b.piece(armoury,"WeaponRackRail",Vector3(x,1.55,-4),Vector3(2.8,.12,.12),b.wood)
		for offset in [-1.2,1.2]:
			b.piece(armoury,"RackPost",Vector3(x+offset,1,-4),Vector3(.12,1.5,.12),b.wood)
		for offset in [-.8,0.0,.8]:
			var musket: Node3D = preload("res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb").instantiate()
			armoury.add_child(musket)
			musket.basis = Basis(Vector3.FORWARD,-PI/2)*Basis(Vector3.RIGHT,PI/2)
			musket.scale = Vector3.ONE * b.stored_weapon_scale("enfield")
			var bounds: AABB = b.weapon_bounds(musket,armoury)
			musket.position += Vector3(x+offset-bounds.get_center().x,.6-bounds.position.y,-3.95-bounds.get_center().z)
	for x in [-25.0,25.0]:
		var cannon := StaticBody3D.new()
		cannon.name = "FortCannonWest" if x < 0 else "FortCannonEast"
		cannon.position = Vector3(signf(x)*69,.08,45)
		cannon.rotation.y = -signf(x)*PI/2
		b.box("GunEmplacement",Vector3(signf(x)*69,.02,45),Vector3(7,.04,7),b.stone)
		b.add_child(cannon)
		cannon.add_to_group("fort_cannons")
		cannon.add_child(preload("res://environment/props/new_assets/wooden_gun_carriage_v1.glb").instantiate())
		var shape := BoxShape3D.new()
		shape.size = Vector3(4.5,1.45,4.7)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position.y = .73
		cannon.add_child(collision)
		preload("res://world/suryagarh/settlements/military_room_finish.gd").emplacement(b,Vector3(signf(x)*69,0,45))
	preload("res://world/suryagarh/settlements/military_detail.gd").prop(armoury,"res://objects/household/storage/crate.tscn",Vector3(-7,.24,3))
	preload("res://world/suryagarh/settlements/military_detail.gd").prop(armoury,"res://objects/household/storage/barrel.tscn",Vector3(7,.24,3))
	preload("res://world/suryagarh/settlements/military_detail.gd").prop(armoury,"res://objects/household/supplies/record_folio.tscn",Vector3(.6,.85,-4))
	preload("res://world/suryagarh/settlements/military_room_finish.gd").armoury(b,armoury)
	var main_details := preload("res://world/suryagarh/settlements/fort_service_detail.gd").new()
	main_details.configure()
	main_details.command_rooms(b)

func staff(b) -> void:
	# Parse one staff asset; duplicate nodes so skeleton names and poses remain independent.
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var path := "res://characters/npcs/motion/fort_staff/fort_staff_rigged_candidate.glb"
	var staff_loaded := document.append_from_file(ProjectSettings.globalize_path(path),state)==OK
	if not staff_loaded:push_error("Cannot load fort staff rig: "+path)
	var template: Node3D=document.generate_scene(state) if staff_loaded else null
	for i in 2:
		var actor := preload("res://characters/npcs/households/fort_staff.gd").new()
		actor.name = "FortCook" if i == 0 else "FortSteward"
		actor.household_job = "Cook" if i == 0 else "Steward"
		actor.movement_enabled = false
		actor.position = Vector3(-41,.42,-75.05) if i == 0 else Vector3(0,.18,-65)
		actor.rotation.y = PI if i == 0 else 0.0
		actor.set_meta("visual_status","candidate_unapproved")
		actor.add_to_group("fort_staff")
		if not staff_loaded:continue
		actor.add_child(template.duplicate())
		b.add_child(actor)

	if template != null:template.free()

	var commander := preload("res://characters/npcs/british/british_npc_actor.gd").new()
	commander.name="FortCommander"
	commander.position=Vector3(-1.8,4.86,-40.9)
	commander.rotation.y=PI
	commander.movement_enabled=false
	commander.set_meta("story_role","resident district commandant issuing village orders")
	commander.set_meta("visual_status","candidate_unapproved")
	commander.add_to_group("fort_staff")
	commander.add_child(preload("res://characters/npcs/british/official_man.glb").instantiate())
	b.add_child(commander)

	for x in [-8.0,8.0]:
		var guard := preload("res://characters/npcs/british/british_npc_actor.gd").new()
		guard.name = "FortGateGuardWest" if x < 0 else "FortGateGuardEast"
		guard.position = Vector3(x,.04,87)
		guard.movement_enabled = false
		guard.set_meta("visual_status","candidate_unapproved")
		guard.add_to_group("fort_guards")
		guard.add_child(preload("res://characters/npcs/british/private_man.glb").instantiate())
		b.add_child(guard)
