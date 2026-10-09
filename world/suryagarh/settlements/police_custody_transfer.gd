extends RefCounted
## Transfers only occur behind a fully opaque screen. No human assets are created.
var owner_node: Node
var layer: CanvasLayer
var curtain: ColorRect
var caption: Label
var sentence_days := 3
const PHASES := ["station_fade_out", "station_fade_in", "booking", "jail_fade_out", "jail_fade_in", "custody_fade_out", "time_passage", "release_fade_in"]

func setup(coordinator: Node) -> void:
	owner_node = coordinator
	layer = CanvasLayer.new()
	layer.layer = 120
	coordinator.add_child(layer)
	curtain = ColorRect.new()
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.color = Color(0,0,0,0)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(curtain)
	caption = Label.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	caption.position = Vector2(-240,-35)
	caption.size = Vector2(480,70)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",26)
	curtain.add_child(caption)
	layer.hide()

func start() -> void:
	layer.show()
	caption.text = "Taken to the police station"
	owner_node.set_phase("station_fade_out")

func opacity(value: float) -> void:
	curtain.color.a = clampf(value,0,1)
	caption.modulate.a = curtain.color.a

func warp(local_position: Vector3) -> void:
	assert(curtain.color.a >= 0.999, "Custody transfer must be hidden")
	var actor: CharacterBody3D = owner_node.suspect
	actor.global_position = owner_node.station.to_global(local_position)
	actor.velocity = Vector3.ZERO
	owner_node.detention.anchor = actor.global_transform

func tick() -> bool:
	var age: float = owner_node.phase_age
	var phase: String = owner_node.phase
	if phase == "custody":
		if age >= owner_node.custody_seconds:
			caption.text = "%d days later" % sentence_days
			owner_node.set_phase("custody_fade_out")
		return true
	if phase not in PHASES: return false
	match phase:
		"station_fade_out":
			opacity(age / 0.7)
			if age >= 0.7:
				warp(Vector3(0,.9,10))
				owner_node.detention.mode = "waiting"
				owner_node.suspect.set_meta("detention_action","waiting")
				owner_node.officer.global_position = owner_node.station.to_global(Vector3(-.8,0,9.8))
				owner_node.officer.travel_speed = 0
				owner_node.officer.duty_state = "idle"
				owner_node.set_phase("station_fade_in")
		"station_fade_in":
			opacity(1.0-age/0.7)
			if age >= 0.7: owner_node.set_phase("booking")
		"booking":
			if age >= 1.8:
				caption.text = "Placed in the jail cell"
				owner_node.set_phase("jail_fade_out")
		"jail_fade_out":
			opacity(age/0.7)
			if age >= 0.7:
				warp(Vector3(7.2,.9,15.2))
				var detention: Node = owner_node.detention
				detention.seat_world = owner_node.station.to_global(Vector3(7.2,.47,14.55))
				detention.floor_world = owner_node.station.to_global(Vector3(7.2,0,15.2))
				detention.seat_rising = false
				detention.mode = "seated"
				owner_node.suspect.set_meta("detention_action","seated")
				owner_node.suspect.set_meta("detention_seat_blend",0.0)
				owner_node.suspect.global_basis = owner_node.station.global_basis
				owner_node.suspect.get_node("VisualRoot").rotation.y = 0
				detention.anchor = owner_node.suspect.global_transform
				owner_node.gate = owner_node.station.get_node("GroundCell0Gate")
				owner_node.gate.set_locked(true)
				owner_node.nav_cache.clear()
				owner_node.set_phase("jail_fade_in")
		"jail_fade_in":
			opacity(1.0-age/0.7)
			if age >= 0.7: owner_node.set_phase("custody")
		"custody_fade_out":
			opacity(age/0.9)
			if age >= 0.9: owner_node.set_phase("time_passage")
		"time_passage":
			if age >= 2.0:
				var clock: Node = owner_node.get_tree().root.find_child("GameTimeSystem",true,false)
				if clock == null:
					owner_node.abort()
					return true
				var morning := (floorf(clock.total_game_minutes/1440.0)+maxi(sentence_days,1))*1440.0+360.0
				clock.advance_minutes(morning-clock.total_game_minutes)
				owner_node.resolve_case()
				owner_node.gate.set_locked(false)
				owner_node.nav_cache.clear()
				owner_node.detention.mode = "waiting"
				owner_node.suspect.set_meta("detention_action","waiting")
				warp(Vector3(0,.9,20))
				owner_node.suspect.health = maxf(owner_node.suspect.health,30.0)
				caption.text = "Morning — released from custody"
				owner_node.set_phase("release_fade_in")
		"release_fade_in":
			opacity(1.0-age/0.9)
			if age >= 0.9:
				owner_node.detention.release_detention()
				owner_node.suspect.inventory.message_requested.emit("Released after %d days" % sentence_days)
				owner_node.route = owner_node.path(owner_node.officer.global_position,owner_node.home,.29)
				owner_node.route_index = 0
				owner_node.officer.detainee = null
				owner_node.officer.duty_state = "return"
				layer.hide()
				owner_node.set_phase("return")
	return true

func abort() -> void:
	if is_instance_valid(layer): layer.hide()
