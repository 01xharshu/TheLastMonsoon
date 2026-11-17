extends Node
## Station boundaries report only an actual guard's sight of an unauthorized entry.
var station: Node3D
var world: Node
var player: CharacterBody3D
var encounters: Node3D
var rebellion: Node
var guards: Array[Node3D]=[]
var inquiry_cached := false
var elapsed := 0.0
var reported_zone := ""

func _ready() -> void:
	station=get_parent().get_parent()
	world=preload("res://systems/world_context.gd").find_world(self)
	for child in get_parent().get_children():
		if child is Node3D and child.has_method("palm_world"):guards.append(child)

func restricted_zone(at: Vector3) -> String:
	var local:=station.to_local(at)
	if absf(local.x)>station.width*.5-.3 or absf(local.z)>station.depth*.5-.3:return ""
	if local.y>station.floor_y+.4:return "upper_offices"
	if absf(local.x-station.stair_x)<1.7 and local.y>1.8:return "upper_offices"
	if local.y<-1.0:return "detention_cellar"
	if local.x>13.3 and local.z<-10.3:return "armoury"
	return ""

func uniform_authorized() -> bool:
	return is_instance_valid(rebellion) and rebellion.disguise and rebellion.outfit.worn

func _process(delta: float) -> void:
	elapsed+=delta
	if elapsed<.25:return
	elapsed=0.0
	if not is_instance_valid(world):return
	if not is_instance_valid(player):player=world.get_node_or_null("Player")
	if not is_instance_valid(encounters):encounters=world.get_node_or_null("CombatEncounters")
	if not is_instance_valid(rebellion):rebellion=world.get_node_or_null("RebellionStory")
	if not inquiry_cached:
		var inquiry: Node=world.get_node_or_null("DevInquiry")
		if inquiry!=null and not inquiry.guards.is_empty():
			guards.append_array(inquiry.guards)
			inquiry_cached=true
	if not is_instance_valid(player) or not is_instance_valid(encounters):return
	if player.global_position.distance_squared_to(station.global_position)>4900.0:return
	if player.health<=0.0 or player.get_meta("story_cinematic",false) or player.get_meta("opening_active",false) or player.get_meta("detention_action","")!="":return
	var zone:=restricted_zone(player.global_position)
	if zone.is_empty():
		reported_zone=""
		return
	if uniform_authorized() or reported_zone==zone:return
	if encounters.wanted:
		for record: Dictionary in encounters.evidence:
			if record.get("kind","")=="station_trespass" and record.get("station_zone","")==zone:
				reported_zone=zone
				return
	for guard in guards:
		if not is_instance_valid(guard) or guard.get_meta("dead",false) or guard.get_meta("knocked_out",false):continue
		if not encounters.visible_to(guard):continue
		var witnesses: Array[String]=[str(guard.get_path())]
		if encounters.record_incident("station_trespass",player.global_position,witnesses,2):
			var record: Dictionary=encounters.evidence[-1]
			record["station_zone"]=zone
			reported_zone=zone
			guard.set_meta("station_alarm_target",player.global_position)
			guard.set_meta("station_alarm_gesture_until",Time.get_ticks_msec()+1450)
			player.inventory.message_requested.emit("Guard: This area is for station staff.")
		return
