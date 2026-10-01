extends RefCounted
const Door = preload("res://objects/hinged_door.gd")
const SecureDoor = preload("res://world/suryagarh/settlements/administrative_secure_door.gd")
const Service = preload("res://world/suryagarh/settlements/administrative_service.gd")
const Actor = preload("res://characters/npcs/british/british_npc_actor.gd")
func build(builder: Node3D,district: Node3D) -> void:
	for room in district.get_children():
		if not room.is_in_group("administrative_buildings"): continue
		var dimensions: Vector2 = room.get_meta("room_dimensions")
		var door = Door.new()
		door.name = "EntranceDoor"
		door.width = 2.8
		door.height = 2.22
		door.label_name = "office door"
		door.position = Vector3(-1.4,.27,dimensions.y/2+.26)
		room.add_child(door)
		door.build(builder.wood)
	var treasury = district.get_node("DistrictTreasury")
	var strongroom = SecureDoor.new()
	strongroom.name = "StrongroomDoor"
	strongroom.width = 3.0
	strongroom.height = 2.6
	strongroom.opened = false
	strongroom.locked = true
	strongroom.position = Vector3(-1.5,.24,-3)
	treasury.add_child(strongroom)
	strongroom.build(builder.wood)
	builder.piece(treasury,"StrongroomDoorHeader",Vector3(0,3.22,-3),Vector3(3,.6,.35),builder.brick)
	station(district.get_node("Collectorate"),"PetitionClerk",Vector3(1.8,.24,-3),"petition","res://characters/npcs/households/merchant.glb")
	station(district.get_node("BritishCourthouse"),"CourtClerk",Vector3(12.8,.24,-7),"court","res://characters/npcs/households/merchant.glb")
	station(treasury,"RevenueClerk",Vector3(-4.2,.24,2),"revenue","res://characters/npcs/households/merchant.glb")
	staff(district.get_node("BritishCourthouse"),"PresidingOfficer",Vector3(-3,.42,-8),"res://characters/npcs/british/official_man.glb")
func staff(room: Node3D,label: String,at: Vector3,path: String) -> Node3D:
	var actor = Actor.new()
	actor.name = label
	actor.position = at
	actor.movement_enabled = false
	actor.set_meta("visual_status","candidate_unapproved")
	actor.set_meta("source_model",path)
	actor.add_to_group("administrative_staff")
	actor.add_child(load(path).instantiate())
	room.add_child(actor)
	var vitality := preload("res://combat/npc_vitality.gd").new()
	vitality.name = "Vitality"
	actor.call_deferred("add_child",vitality)
	return actor
func station(room: Node3D,label: String,at: Vector3,role: String,path: String) -> void:
	var actor := staff(room,label,at,path)
	var service = Service.new()
	service.name = label+"Service"
	service.position = at
	service.role = role
	service.staff = actor
	room.add_child(service)
