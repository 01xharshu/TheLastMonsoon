extends CanvasLayer
## Root-owned artwork survives world loading, scene replacement and the first draw.
const Style = preload("res://ui/menu_style.gd")
const ARRIVAL = preload("res://assets/ui/backgrounds/monsoon_arrival.png")
var world_path := "res://world/suryagarh/suryagarh_world.tscn"
var panel: Control
var status: Label
var progress_bar: ProgressBar

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var art := TextureRect.new()
	art.texture = ARRIVAL
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(art)
	var scrim := ColorRect.new()
	scrim.color = Color(0.008, 0.014, 0.012, 0.3)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(scrim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	margin.offset_top = -150
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.theme = Style.make_theme()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	status = Style.label("Preparing your journey…", 24)
	column.add_child(status)
	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.08, 0.10, 0.09, 0.85)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Style.GOLD
	progress_bar.add_theme_stylebox_override("background", track)
	progress_bar.add_theme_stylebox_override("fill", fill)
	progress_bar.custom_minimum_size.y = 4
	column.add_child(progress_bar)

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()

func _draw_frame() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

func begin(slot: int) -> bool:
	var saves := get_tree().root.get_node("SaveManager")
	if slot > 0 and saves.read_slot(slot).is_empty():
		queue_free()
		return false
	# Present artwork before any expensive loading or world construction.
	await _draw_frame()
	if not ResourceLoader.exists(world_path):
		queue_free()
		return false
	# Compile script metadata on the main thread before the loader reads it.
	# Godot 4.7.2 otherwise leaves zero-reference objects after this scene load.
	var scripts_to_keep: Array[Script] = []
	if not await _prepare_scene_scripts(world_path, scripts_to_keep):
		queue_free()
		return false
	var error := ResourceLoader.load_threaded_request(world_path)
	if error != OK:
		queue_free()
		return false
	var progress: Array = []
	while true:
		var state := ResourceLoader.load_threaded_get_status(world_path, progress)
		if state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			queue_free()
			return false
		if not progress.is_empty(): progress_bar.value = float(progress[0]) * 90.0
		if state == ResourceLoader.THREAD_LOAD_LOADED: break
		await get_tree().process_frame
	var packed := ResourceLoader.load_threaded_get(world_path) as PackedScene
	scripts_to_keep.clear()
	if packed == null:
		queue_free()
		return false
	status.text = "Entering India, 1857…" if slot == 0 else "Returning to your journey…"
	progress_bar.value = 95.0
	await _draw_frame()
	var previous_slot: int = saves.pending_slot
	saves.pending_slot = slot
	get_tree().paused = false
	error = get_tree().change_scene_to_packed(packed)
	if error != OK:
		saves.pending_slot = previous_slot
		queue_free()
		return false
	await get_tree().scene_changed
	# Save restoration/opening setup is deferred by the world. Wait for it, then draw.
	while saves.pending_slot >= 0:
		await get_tree().process_frame
	var world := get_tree().current_scene
	var opening := world.get_node_or_null("OpeningSequence")
	# Keep artwork over the opening's initial black cover, without altering its timeline.
	while is_instance_valid(opening) and opening.state == "night" and opening.elapsed < 1.6:
		await get_tree().process_frame
	progress_bar.value = 100.0
	await _draw_frame()
	set_process_input(false)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reveal := create_tween()
	reveal.tween_property(panel, "modulate:a", 0.0, 0.65)
	await reveal.finished
	queue_free()
	return true

func _prepare_scene_scripts(path: String, scripts: Array[Script]) -> bool:
	var pending: Array[String] = [path]
	var seen: Dictionary = {}
	while not pending.is_empty():
		var current: String = pending.pop_back()
		if seen.has(current): continue
		seen[current] = true
		for dependency in ResourceLoader.get_dependencies(current):
			var fields := dependency.split("::")
			var source: String = fields[fields.size()-1]
			if source.begins_with("uid://"):
				var uid := ResourceUID.text_to_id(source)
				source = ResourceUID.get_id_path(uid) if ResourceUID.has_id(uid) else ""
			if seen.has(source): continue
			if source.get_extension() == "gd":
				seen[source] = true
				var script := ResourceLoader.load(source, "GDScript") as Script
				if script == null: return false
				scripts.append(script)
				if scripts.size()%3 == 0: await get_tree().process_frame
			elif source.get_extension() in ["tscn", "scn", "tres", "res"]:
				pending.append(source)
	return true
