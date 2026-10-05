extends Node3D
## Stable job IDs and state own rewards; world targets never grant money themselves.
const Target = preload("res://world/suryagarh/errands/errand_target.gd")
const Actor = preload("res://characters/npcs/households/household_npc_actor.gd")
const FONT = preload("res://assets/ui/fonts/MFBOldstyle-Regular.otf")
const JOBS := {
	"port_delivery": {"title":"A consignment from the ship port", "offer":"office", "pickup":"port_cargo", "goal":"office", "kind":"delivery", "pay":18, "description":"Dispatch clerk: Our ship consignment is waiting at the port warehouse. Collect the sealed goods and bring them back to this counting house. Eighteen rupees after handover."},
	"urgent_medicine": {"title":"Medicine for a sick neighbour", "offer":"medicine_request", "pickup":"medicine_supply", "goal":"medicine_request", "kind":"delivery", "pay":10, "description":"Neighbour: Please fetch the prepared medicine packet from the market dispenser and bring it to me. My family is waiting. Ten rupees on delivery."},
	"emergency_money": {"title":"Emergency money for a family", "offer":"money_sender", "pickup":"money_sender", "goal":"money_receiver", "kind":"delivery", "pay":12, "description":"Traveller: Carry this sealed purse to my brother by the port. It belongs to his family and cannot be spent. Your twelve-rupee wage is separate."},
	"family_cart": {"title":"Bring my brother home by cart", "offer":"office", "pickup":"passenger", "goal":"family_home", "kind":"escort", "pay":20, "description":"Dispatch clerk: My brother is waiting by the village cart stand. Bring him to our home by passenger cart. You may borrow the cart waiting beside him, or use another passenger cart. Stop beside him to board, then stop at the home to let him out. Twenty rupees on arrival."},
	"road_meal": {"title":"A meal for a stranded traveller", "offer":"road", "goal":"road", "kind":"aid", "pay":2, "description":"Traveller: I have walked all morning without food. Could you spare one roti? The market relief fund pays two rupees for a meal delivered here."},
	"merchant_parcel": {"title":"Cloth parcel for the market", "offer":"office", "goal":"market", "kind":"delivery", "pay":8, "description":"Counting-house clerk: Collect our sealed cloth parcel from the dispatch table, then deliver it to the market receiver. Eight rupees on delivery; no deposit."},
	"market_sort": {"title":"Sort the market stores", "offer":"market", "goal":"work", "kind":"work", "pay":5, "description":"Market receiver: Put the sacks at the sorting table in order. Hold the work interaction for three seconds, then return to me for five rupees."},
}
var pending_passenger: Dictionary = {}
var expanded: Node
var stages: Dictionary = {}
# Last paid day remains even when a new shift is accepted or cancelled.
var completed_days: Dictionary = {}
var active := ""
var targets: Dictionary = {}
var player: CharacterBody3D
var panel: PanelContainer
var rows: VBoxContainer
var previous_mouse := Input.MOUSE_MODE_CAPTURED
var previous_pause := false
var source := ""
var paper_title: Label
var paper_body: Label
var floor_levels: Dictionary = {}
var destination_marker: Control
var ui_stage: Control
var toast: Label
var toast_seconds := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = get_parent().get_node("Player")
	_build_ui()
	call_deferred("_build_world")

func _build_world() -> void:
	await get_tree().physics_frame
	# Flat surveyed village road and the existing merchant counting house.
	_person("road", "StrandedTraveller", Vector3(-378,7.2,315), "village_farmer")
	_person("office", "DispatchClerk", Vector3(-365.4,7.44,312.7), "village_farmer")
	_person("market", "MarketReceiver", Vector3(-389,7.2,321), "village_woman")
	_prop("board", Vector3(-383,8.45,319), "WORK NOTICES", Vector3(1.35,1.45,.12))
	_prop("parcel", Vector3(-368.6,8.34,311.35), "CLOTH DISPATCH", Vector3(.45,.25,.35))
	_prop("work", Vector3(-391,7.85,321), "SORTING TABLE", Vector3(1.25,.18,.65))
	for x in [-.36,.36]:
		var sack: Node3D = load("res://objects/household/grain_sack.tscn").instantiate()
		sack.position = Vector3(x,.1,0); sack.scale = Vector3.ONE * .6
		targets.work.add_child(sack)
		if sack is CollisionObject3D: sack.collision_layer = 0
		for body in sack.find_children("*","CollisionObject3D",true,false): body.collision_layer = 0
	targets.work.hold_duration = 3.0
	targets.work.interaction_text = "Sort market stores"
	for id in ["road","market","board","work"]:
		var target: Node3D = targets[id]
		var query := PhysicsRayQueryParameters3D.create(Vector3(target.global_position.x,9.1,target.global_position.z),Vector3(target.global_position.x,0,target.global_position.z))
		var excluded: Array[RID] = []
		for entry in targets.values():
			excluded.append(entry.get_rid())
			if entry.person != null: excluded.append(entry.person.get_node("BodyCollider").get_rid())
		query.exclude = excluded
		query.collision_mask = 1
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var ground: float = hit.position.y if not hit.is_empty() else 7.2
		floor_levels[id] = ground
		if target.person != null: target.person.global_position.y = ground
		else: target.global_position.y = ground + (1.25 if id == "board" else .65)
	floor_levels.office = 7.44; floor_levels.parcel = 7.44
	expanded = preload("res://world/suryagarh/errands/expanded_jobs.gd").new()
	expanded.name = "ExpandedJobs"; add_child(expanded); expanded.configure(self)
	expanded.restore_trip(pending_passenger); pending_passenger.clear()
	for id in ["board","work"]:
		var post := MeshInstance3D.new()
		var mesh := BoxMesh.new(); mesh.size = Vector3(.12,1.4,.12)
		post.mesh = mesh; post.position = Vector3(0,-.72,-.1)
		targets[id].add_child(post)

func _person(id: String, label: String, at: Vector3, model: String) -> void:
	var actor := Actor.new()
	actor.name = label; actor.position = at
	actor.movement_enabled = false
	actor.process_mode = Node.PROCESS_MODE_PAUSABLE
	actor.movement_profile = &"female" if model == "village_woman" else &"male"
	var document := GLTFDocument.new(); var state := GLTFState.new()
	var path := "res://WorkingAssets/NPCs/%s/%s_rigged_candidate.glb" % [model,model]
	if model == "errand_passenger": path = "res://WorkingAssets/NPCs/errand_passenger/errand_passenger.glb"
	if document.append_from_file(ProjectSettings.globalize_path(path),state) != OK:
		actor.free(); push_error("Errand actor could not load: " + path); return
	actor.add_child(document.generate_scene(state))
	add_child(actor)
	var target := Target.new(); target.name = label + "Conversation"
	target.manager = self; target.endpoint = id; target.person = actor
	target.position.y = .9
	actor.add_child(target); targets[id] = target

func _prop(id: String, at: Vector3, caption: String, size: Vector3) -> void:
	var target := Target.new(); target.name = id.capitalize()
	target.manager = self; target.endpoint = id; target.position = at
	add_child(target); targets[id] = target
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = size; visual.mesh = mesh
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(.64,.49,.29); mat.roughness = .95
	visual.material_override = mat; target.add_child(visual)
	var label := Label3D.new(); label.text = caption
	label.font = FONT; label.font_size = 32; label.pixel_size = .002
	label.position = Vector3(0,.12,size.z/2+.015); label.outline_size = 0
	label.modulate = Color(.16,.10,.05); target.add_child(label)

func _near(id: String) -> bool:
	return targets.has(id) and targets[id].interaction_available() and player.global_position.distance_to(targets[id].global_position) <= targets[id].interaction_max_distance

func use_endpoint(id: String, actor: CharacterBody3D) -> void:
	if actor != player or not _near(id): return
	if expanded != null and expanded.use_endpoint(id): return
	if not active.is_empty():
		var job: Dictionary = JOBS[active]
		var stage: String = stages.get(active, "")
		if id == str(job.get("pickup","parcel")) and job.kind == "delivery" and stage == "accepted":
			_clear_job_waypoint()
			stages[active] = "carrying"; _message("Collected: " + job.title + ". " + objective(active)); return
		if id == "work" and job.kind == "work" and stage == "accepted":
			_clear_job_waypoint()
			stages[active] = "worked"; _message("Stores sorted. Return to the market receiver for your wage."); return
		if id == job.goal and job.kind == "delivery" and stage == "carrying":
			_finish(active); return
		if id == job.goal and job.kind == "aid":
			var inventory: InventoryComponent = player.get_node("InventoryComponent")
			if not inventory.remove_item("roti",1): _message("Bring one roti to the stranded traveller."); return
			_finish(active); return
		if id == job.offer and job.kind == "work" and stage == "worked":
			_finish(active); return
	if id in ["parcel","work"]:
		_message("Speak to the clerk or receiver and accept the job first."); return
	open_panel(id)

func current_job_day() -> int:
	return int(floor(get_parent().get_node("GameTimeSystem").total_game_minutes/1440.0))+1

func repeatable(id: String) -> bool:
	return id in ["merchant_parcel","market_sort","port_delivery"]

func job_available(id: String) -> bool:
	if not JOBS.has(id): return false
	if completed_days.has(id):
		return repeatable(id) and current_job_day() > int(completed_days[id])
	return stages.get(id, "") != "completed"

func accept(id: String) -> bool:
	if not active.is_empty() or not job_available(id): return false
	var job: Dictionary = JOBS[id]
	if source != "board" and source != job.offer: return false
	if not _near(source): return false
	active = id; stages[id] = "accepted"
	close_panel(); _message("Job accepted: " + job.title + ". " + objective(id))
	return true

func _finish(id: String) -> void:
	# The caller verifies real progress, receiver and range before payment.
	if active != id or not job_available(id): return
	_clear_job_waypoint()
	completed_days[id] = current_job_day()
	stages[id] = "completed"; active = ""
	player.get_node("InventoryComponent").add_item("rupees",int(JOBS[id].pay))
	if JOBS[id].kind == "aid": player.get_node("FameComponent").award_help()
	_message("Completed: " + JOBS[id].title)

func cancel() -> void:
	if active.is_empty(): return
	_clear_job_waypoint()
	if expanded != null: expanded.release_passenger()
	stages.erase(active); active = ""
	close_panel(); _message("Job cancelled. Entrusted goods returned; no wage paid.")

func objective(id: String) -> String:
	var job: Dictionary = JOBS[id]
	if job.has("pickup"):
		if job.kind == "escort": return "Stop a passenger cart beside the waiting brother." if stages.get(id,"") == "accepted" else "Drive the passenger home and stop to let him out."
		var stops := {"port_cargo":"the consignment at the port warehouse", "office":"the goods to the counting-house clerk", "medicine_supply":"the medicine from the market dispenser", "medicine_request":"the medicine to the worried neighbour", "money_sender":"the sealed purse from the sender", "money_receiver":"the sealed purse to the family at the port"}
		var endpoint: String = str(job.pickup) if stages.get(id,"") == "accepted" else str(job.goal)
		return ("Collect " if stages.get(id,"") == "accepted" else "Deliver ") + str(stops.get(endpoint,job.title))
	if job.kind == "aid": return "Bring one roti to the traveller on the village road."
	if job.kind == "delivery": return "Deliver the parcel to the market receiver." if stages.get(id, "") == "carrying" else "Collect the sealed cloth parcel inside the counting house."
	return "Return to the market receiver for payment." if stages.get(id, "") == "worked" else "Hold the interaction at the sorting table for three seconds."

func export_state() -> Dictionary:
	return {"active":active, "stages":stages.duplicate(true), "completed_days":completed_days.duplicate(true), "passenger_trip":expanded.export_trip() if expanded != null else pending_passenger.duplicate(true)}

func restore_state(data: Dictionary) -> void:
	if expanded != null: expanded.release_passenger()
	toast_seconds = 0.0
	if is_instance_valid(toast): toast.hide()
	stages.clear(); completed_days.clear(); active = ""
	var saved: Dictionary = data.get("stages",{}) if data.get("stages",{}) is Dictionary else {}
	var paid: Dictionary = data.get("completed_days",{}) if data.get("completed_days",{}) is Dictionary else {}
	for id in JOBS:
		if paid.has(id) and (paid[id] is int or paid[id] is float) and is_finite(float(paid[id])) and float(paid[id]) >= 1:
			completed_days[id] = int(paid[id])
		var stage: String = str(saved.get(id,""))
		if stage == "completed":
			stages[id] = stage
			# Old saves lack dates: preserve their reward and unlock paid work tomorrow.
			if not completed_days.has(id): completed_days[id] = current_job_day()
	var requested: String = str(data.get("active",""))
	if JOBS.has(requested) and not stages.has(requested) and job_available(requested):
		var stage: String = str(saved.get(requested,""))
		var kind: String = JOBS[requested].kind
		if stage == "accepted" or (stage == "carrying" and kind in ["delivery","escort"]) or (stage == "worked" and kind == "work"):
			active = requested; stages[active] = stage
	pending_passenger = data.get("passenger_trip",{}).duplicate(true) if data.get("passenger_trip",{}) is Dictionary else {}
	if expanded != null:
		expanded.restore_trip(pending_passenger); pending_passenger.clear()

func _message(value: String) -> void:
	toast.text = value; toast_seconds = 5.0; toast.show()

func _build_ui() -> void:
	var layer := CanvasLayer.new(); layer.layer = 30; add_child(layer)
	ui_stage = Control.new(); ui_stage.size = Vector2(1280,720)
	ui_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(ui_stage)
	_resize_ui(); get_viewport().size_changed.connect(_resize_ui)
	destination_marker = preload("res://world/suryagarh/errands/destination_marker.gd").new()
	destination_marker.name = "DestinationMarker"; destination_marker.manager = self
	ui_stage.add_child(destination_marker)
	toast = Label.new(); toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.offset_left = -320; toast.offset_right = 320; toast.offset_top = 565; toast.offset_bottom = 650
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_override("font",FONT); toast.add_theme_font_size_override("font_size",20)
	toast.add_theme_color_override("font_shadow_color",Color.BLACK); toast.add_theme_constant_override("shadow_offset_x",2); toast.add_theme_constant_override("shadow_offset_y",2)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui_stage.add_child(toast); toast.hide()
	var shade := ColorRect.new(); shade.color = Color(.012,.011,.009,1)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui_stage.add_child(shade)
	panel = PanelContainer.new(); panel.name = "ErrandJournal"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 55; panel.offset_right = -55; panel.offset_top = 45; panel.offset_bottom = -45
	panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); shade.add_child(panel)
	var columns := HBoxContainer.new(); columns.add_theme_constant_override("separation",55); panel.add_child(columns)
	var paper := preload("res://world/suryagarh/errands/errand_paper.gd").new()
	paper.custom_minimum_size.x = 390; paper.size_flags_vertical = Control.SIZE_EXPAND_FILL; columns.add_child(paper)
	var ink := VBoxContainer.new(); ink.position = Vector2(35,145); ink.custom_minimum_size.x = 320
	ink.add_theme_constant_override("separation",20); paper.add_child(ink)
	paper_title = Label.new(); paper_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	paper_title.add_theme_font_override("font",FONT); paper_title.add_theme_color_override("font_color",Color(.23,.15,.08))
	paper_title.add_theme_font_size_override("font_size",23); ink.add_child(paper_title)
	paper_body = Label.new(); paper_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	paper_body.add_theme_font_override("font",FONT); paper_body.add_theme_color_override("font_color",Color(.23,.15,.08))
	paper_body.add_theme_font_size_override("font_size",19); ink.add_child(paper_body)
	var scroll := ScrollContainer.new(); scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL; columns.add_child(scroll)
	rows = VBoxContainer.new(); rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",16); scroll.add_child(rows)
	shade.hide()

func _resize_ui() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := minf(viewport_size.x/1280.0,viewport_size.y/720.0)
	ui_stage.scale = Vector2.ONE*factor
	ui_stage.position = (viewport_size-ui_stage.size*factor)*.5

func _line(value: String) -> void:
	var label := Label.new(); label.text = value; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font",FONT); label.add_theme_font_size_override("font_size",20)
	rows.add_child(label)

func _button(value: String, action: Callable) -> void:
	var button := Button.new(); button.text = value; button.pressed.connect(action)
	button.add_theme_font_override("font",FONT); rows.add_child(button)

func open_panel(id: String = "journal") -> void:
	if panel.get_parent().visible or get_tree().paused: return
	if player.get_meta("map_open",false) or player.get_meta("scroll_open",false) or player.get_meta("document_busy",false) or player.get_meta("weapon_wheel_open",false) or player.get_meta("climbing",false) or (player.has_meta("mounted_vehicle") and player.get_meta("mounted_vehicle") != null) or player.get_meta("rest_action","") != "" or player.get_meta("river_action","") != "" or player.health <= 0 or player.inventory_ui.is_open(): return
	source = id
	for child in rows.get_children(): rows.remove_child(child); child.queue_free()
	paper_title.text = "PUBLIC WORK NOTICES" if active.is_empty() else JOBS[active].title.to_upper()
	paper_body.text = "Paid errands and assistance\n\nSpeak to the counting house, market receiver or road traveller.\n\nAgreed wages are paid after the work is finished." if active.is_empty() else objective(active) + "\n\nAgreed wage: %d rupees" % int(JOBS[active].pay)
	_line("WORK NOTICES" if id == "board" else ("ARJUN'S ERRANDS" if id == "journal" else "A REQUEST FOR HELP"))
	_line("One errand at a time · Payment on completion")
	_line("Merchant delivery and market work are available once each game day.")
	if not active.is_empty():
		_line(JOBS[active].description)
		_line(JOBS[active].title + " — " + str(JOBS[active].pay) + " rupees")
		_line(objective(active))
		_button("Mark next stop on map", _mark_next)
		_button("Cancel this errand", cancel)
	else:
		for job_id in JOBS:
			var job: Dictionary = JOBS[job_id]
			if id not in ["journal","board",job.offer]: continue
			if not job_available(job_id):
				_line(job.title + (" — Paid today · Return tomorrow" if repeatable(job_id) else " — Completed")); continue
			_line(job.description)
			if id != "journal": _button("Accept · %d rupees" % int(job.pay), accept.bind(job_id))
		if id == "journal": _line("Find work at the road traveller, counting house, market receiver or work notices near the market. J opens this journal.")
	_button("Leave", close_panel)
	previous_mouse = Input.mouse_mode; previous_pause = get_tree().paused
	get_tree().paused = true; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel.get_parent().show()
	for child in rows.get_children():
		if child is Button: child.grab_focus(); break

func next_endpoint() -> String:
	if active.is_empty(): return ""
	var job: Dictionary = JOBS[active]
	if job.has("pickup") and stages[active] == "accepted": return str(job.pickup)
	if job.kind == "delivery" and stages[active] == "accepted": return "parcel"
	if job.kind == "work" and stages[active] == "worked": return "market"
	return job.goal

func tracked_objective() -> String:
	if active.is_empty(): return ""
	if active == "family_cart" and expanded != null:
		if expanded.transfer == "boarding": return "Wait for your passenger to board the cart"
		if expanded.transfer == "exiting": return "Let your passenger step down safely"
	if JOBS[active].has("pickup"): return objective(active)
	match next_endpoint():
		"parcel": return "Collect the cloth parcel at the counting house"
		"market": return "Deliver the cloth parcel to the market receiver" if JOBS[active].kind == "delivery" else "Collect your wage from the market receiver"
		"work": return "Sort the sacks at the market table"
		"road": return "Bring one roti to the stranded traveller"
	return "Go to the errand destination"

func destination() -> Dictionary:
	var next := next_endpoint()
	if targets.has(next):
		var target: Interactable = targets[next]
		if not target.interaction_available(): return {}
		var labels := {"parcel":"Counting house · Cloth parcel", "market":"Market receiver", "work":"Market sorting table", "road":"Roadside traveller"}
		var extra_height := 1.0 if target.get("person") != null else .35
		return {"position":target.interaction_anchor()+Vector3.UP*extra_height, "label":labels.get(next,"Errand destination"), "endpoint":next}
	if not active.is_empty(): return {}
	var waypoint: Vector2 = player.get_node("UI/WorldMap").waypoint
	if not waypoint.is_finite(): return {}
	var ground: float = get_parent().layout.height(waypoint.x,waypoint.y)
	return {"position":Vector3(waypoint.x,ground+1.5,waypoint.y),"label":"Map destination", "endpoint":""}

func _clear_job_waypoint() -> void:
	var next := next_endpoint()
	if not targets.has(next): return
	var map: Control = player.get_node("UI/WorldMap")
	var p: Vector3 = targets[next].global_position
	if map.waypoint.distance_to(Vector2(p.x,p.z)) < .1: map.waypoint = Vector2(INF,INF)

func _mark_next() -> void:
	var next := next_endpoint()
	if not targets.has(next): return
	var pos: Vector3 = targets[next].global_position
	player.get_node("UI/WorldMap").waypoint = Vector2(pos.x,pos.z)
	close_panel(); _message("Follow the destination marker. Distance updates as you travel.")

func close_panel() -> void:
	if not panel.get_parent().visible: return
	panel.get_parent().hide(); get_tree().paused = previous_pause; Input.mouse_mode = previous_mouse

func _process(delta: float) -> void:
	if get_tree().paused: return
	toast_seconds = maxf(0.0,toast_seconds-delta)
	if toast_seconds <= 0.0: toast.hide()

func _input(event: InputEvent) -> void:
	if panel.get_parent().visible:
		if event.is_action_pressed("ui_cancel"): close_panel(); get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_J:
		open_panel(); get_viewport().set_input_as_handled()
