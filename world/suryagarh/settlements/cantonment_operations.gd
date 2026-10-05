extends Node3D
## Authored service rules, not historical tariffs. Save state lives in this ledger.
const Service = preload("res://world/suryagarh/settlements/institution_service.gd")
const Horse = preload("res://horses/stable_horse.gd")
var ledger: Dictionary = {}
var stock := {"ration":12,"fodder":16,"dressings":8}
var stock_day := 1
var pending: Dictionary = {}
var patient: CharacterBody3D
var horse: CharacterBody3D
var clock: Node
var district: Node3D
var bell: MeshInstance3D
var bell_rest := Transform3D.IDENTITY
var bell_sound: AudioStreamPlayer3D
var bell_elapsed := 0.0
var bell_cooldown := 0.0
var chapel_phase := "closed"

func configure(site: Node3D) -> void:
	district = site
	add_to_group("institution_operations")
	clock = get_tree().current_scene.get_node("GameTimeSystem")
	stock_day = clock.current_day
	clock.time_changed.connect(_time_changed)
	var workers := district.get_node("ServiceWorkplaces")
	station("hospital",district.get_node("MilitaryHospital"),Vector3(.9,.24,-.5),workers.workers[2])
	station("issue",district.get_node("GrainFodderWarehouse"),Vector3(-6,.24,2.7),workers.workers[0])
	station("fodder",district.get_node("GrainFodderWarehouse"),Vector3(-4.3,.24,2.7),workers.workers[0])
	horse = Horse.new()
	horse.name = "CantonmentHorse"
	district.get_node("CavalryStables").add_child(horse)
	horse.position = Vector3(-10,.24,-1.7)
	horse.rotation.y = PI
	for entry in [["feed",Vector3(-10,.24,1.5)],["water",Vector3(-8.4,.24,1.5)],["groom",Vector3(-11.6,.24,1.5)]]:
		station(entry[0],district.get_node("CavalryStables"),entry[1],workers.workers[1])
	station("bell",district.get_node("CantonmentChurch"),Vector3(0,.24,5.7),workers.workers[3])
	station("worship",district.get_node("CantonmentChurch"),Vector3(-3.8,.44,-3.8),workers.workers[3])
	bell = district.get_node("ServiceWorkplaces/ChapelBell")
	bell_rest = bell.transform
	bell_sound = AudioStreamPlayer3D.new()
	bell_sound.name = "ChapelBellAudio"
	bell_sound.stream = _bell_stream()
	bell_sound.max_distance = 100
	bell_sound.unit_size = 12
	bell.add_child(bell_sound)
	_time_changed(clock.current_day,clock.current_hour,clock.current_minute)

func station(id: String,room: Node3D,at: Vector3,attendant: Node3D) -> void:
	var service := Service.new()
	service.name = id.capitalize()+"Service"
	service.service_id = id
	service.operations = self
	service.staff = attendant
	service.position = at
	room.add_child(service)

func _time_changed(day: int,hour: int,_minute: int) -> void:
	# A time rewind never replenishes supplies or reopens an already used service.
	if day > stock_day:
		stock_day = day
		stock = {"ration":12,"fodder":16,"dressings":8}
	chapel_phase = "service" if hour == 8 or hour == 18 else "closed"
	set_meta("chapel_phase",chapel_phase)

func request(id: String,actor: CharacterBody3D) -> bool:
	var inv: InventoryComponent = actor.get_node("InventoryComponent")
	if not pending.is_empty():
		inv.message_requested.emit("Finish the current service first")
		return false
	if actor.health <= 0 or (actor.has_meta("mounted_vehicle") and actor.get_meta("mounted_vehicle") != null): return false
	if id != "bell" and id != "worship" and (clock.current_hour < 6 or clock.current_hour >= 20):
		inv.message_requested.emit("Services reopen at six in the morning")
		return false
	var key := id+"/"+str(clock.current_day)
	if ledger.has(key):
		inv.message_requested.emit("This service has already been completed today")
		return false
	match id:
		"hospital":
			if actor.health >= actor.MAX_HEALTH: return false
			if inv.get_item_count("rupees") < 2 or stock.dressings <= 0:
				inv.message_requested.emit("Treatment needs 2 rupees and an available dressing")
				return false
		"issue":
			if stock.ration <= 0: return false
		"fodder":
			if stock.fodder <= 0: return false
		"feed", "water", "groom":
			if horse.vitality.dead or horse.rider != null or horse.position.distance_to(Vector3(-10,.24,-1.7)) > 4:
				inv.message_requested.emit("Bring the living horse back to its stable bay")
				return false
			if id == "feed" and not inv.has_item("stable_fodder"): return false
			if id == "water" and inv.stored_water_liters < .5: return false
		"worship":
			if chapel_phase != "service":
				inv.message_requested.emit("Chapel service is at eight in the morning and six in the evening")
				return false
		"bell":
			if bell_cooldown > 0: return false
			bell_elapsed = 3
			bell_cooldown = 5
			bell_sound.play()
			return true
		_: return false
	patient = actor
	pending = {"id":id,"key":key,"remaining":6.0 if id == "hospital" else 3.0,"start":actor.global_position}
	inv.message_requested.emit("Receiving treatment — remain nearby" if id == "hospital" else "Service underway — remain nearby")
	return true

func _process(delta: float) -> void:
	bell_cooldown = maxf(0,bell_cooldown-delta)
	if bell_elapsed > 0:
		bell_elapsed = maxf(0,bell_elapsed-delta)
		bell.transform = bell_rest
		bell.rotation.z += sin(bell_elapsed*9)*.22*bell_elapsed/3
		if bell_elapsed == 0: bell.transform = bell_rest
	if pending.is_empty(): return
	if not is_instance_valid(patient) or patient.health <= 0 or patient.global_position.distance_to(pending.start) > 2.5 or (patient.has_meta("mounted_vehicle") and patient.get_meta("mounted_vehicle") != null):
		cancel()
		return
	var id: String = pending.id
	var attendant: Node3D = district.find_child(id.capitalize()+"Service",true,false).staff
	if attendant.get_meta("dead",false) or attendant.get_meta("knocked_out",false):
		cancel()
		return
	pending.remaining -= delta
	if pending.remaining <= 0: _finish()

func cancel() -> void:
	if is_instance_valid(patient): patient.get_node("InventoryComponent").message_requested.emit("Service cancelled; no payment or supplies taken")
	pending.clear()
	patient = null

func _finish() -> void:
	var inv: InventoryComponent = patient.get_node("InventoryComponent")
	var id: String = pending.id
	# Recheck mutable resources at transfer time; cancellation/retry cannot duplicate rewards.
	match id:
		"hospital":
			if inv.get_item_count("rupees") < 2 or stock.dressings <= 0 or patient.health >= patient.MAX_HEALTH:
				cancel(); return
			inv.remove_item("rupees",2)
			stock.dressings -= 1
			patient.health = minf(patient.MAX_HEALTH,patient.health+50)
		"issue":
			if stock.ration <= 0: cancel(); return
			stock.ration -= 1
			inv.add_item("roti",2)
		"fodder":
			if stock.fodder <= 0: cancel(); return
			stock.fodder -= 1
			inv.add_item("stable_fodder",1)
		"feed", "water", "groom":
			if horse.vitality.dead or horse.rider != null or horse.position.distance_to(Vector3(-10,.24,-1.7)) > 4: cancel(); return
			if id == "feed":
				if not inv.has_item("stable_fodder"): cancel(); return
				inv.remove_item("stable_fodder",1)
			if id == "water":
				if inv.stored_water_liters < .5: cancel(); return
				inv.stored_water_liters -= .5
				inv._emit_water_changed()
			horse.set_meta("care_"+id,clock.current_day)
		"worship":
			if chapel_phase != "service": cancel(); return
	ledger[pending.key] = true
	inv.message_requested.emit("Service completed")
	pending.clear()
	patient = null

func export_state() -> Dictionary:
	# Mid-service saves restore to an uncharged idle state, never an unpaid reward.
	return {"ledger":ledger.duplicate(true),"stock":stock.duplicate(true),"stock_day":stock_day,"horse_care":{"feed":horse.get_meta("care_feed",0),"water":horse.get_meta("care_water",0),"groom":horse.get_meta("care_groom",0)}}

func restore_state(data: Dictionary) -> void:
	cancel()
	ledger.clear()
	var saved: Variant = data.get("ledger",{})
	if saved is Dictionary:
		for key in saved:
			if saved[key] == true: ledger[str(key)] = true
	stock_day = maxi(1,int(data.get("stock_day",clock.current_day)))
	var supplies: Variant = data.get("stock",{})
	for key in stock:
		stock[key] = clampi(int(supplies.get(key,stock[key])),0,16) if supplies is Dictionary else stock[key]
	var care: Variant = data.get("horse_care",{})
	if care is Dictionary:
		for key in ["feed","water","groom"]: horse.set_meta("care_"+key,maxi(0,int(care.get(key,0))))
	_time_changed(clock.current_day,clock.current_hour,clock.current_minute)

func _bell_stream() -> AudioStreamWAV:
	# Original synthesized struck-metal cue; editable generation remains here.
	var samples := PackedByteArray()
	samples.resize(22050*3*2)
	for i in 22050*3:
		var t := float(i)/22050
		var value := 0.0
		for harmonic in [[390.0,1.0],[810.0,.5],[1120.0,.28],[1680.0,.16]]:
			value += sin(TAU*harmonic[0]*t)*harmonic[1]*exp(-t*(1.6+harmonic[1]))
		var pcm := int(clampf(value*.35,-1,1)*32767)
		samples.encode_s16(i*2,pcm)
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	sound.data = samples
	return sound
