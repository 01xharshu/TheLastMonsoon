extends CanvasLayer
## Root-owned artwork survives world loading, scene replacement and the first draw.
const Startup = preload("res://systems/world_startup.gd")
const Style = preload("res://ui/menu_style.gd")
const ARRIVAL = preload("res://assets/ui/backgrounds/monsoon_arrival.png")
var world_path := "res://world/suryagarh/suryagarh_world.tscn"
var panel: Control
var status: Label
var progress_bar: ProgressBar
var activity: Label
var loading_elapsed := 0.0
var timings: Dictionary = {}

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
	var status_row := HBoxContainer.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(status)
	activity = Style.label("·", 24)
	activity.custom_minimum_size.x = 50
	activity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_row.add_child(activity)
	column.add_child(status_row)
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

func _process(delta: float) -> void:
	loading_elapsed += delta
	activity.text = "·".repeat(1 + int(loading_elapsed * 3.0) % 3)
	if Startup.current != null:
		status.text = Startup.current.stage

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
		if not progress.is_empty(): progress_bar.value = 25.0 + float(progress[0]) * 65.0
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
	var session := Startup.start(get_tree())
	# Suspend gameplay while asynchronous builders populate the same world.
	get_tree().paused = true
	var phase_start := Time.get_ticks_usec()
	var instance := packed.instantiate()
	timings["instantiate_ms"] = (Time.get_ticks_usec()-phase_start)/1000.0
	var terrain_bodies: Array[Dictionary] = []
	var terrain_task := -1
	var scenery_task := -1
	var scenery_tiles: Array[Dictionary] = []
	var landscape := instance.get_node_or_null("Landscape")
	if landscape != null:
		# Concave terrain bodies register expensively in Jolt. Enter them in
		# batches after the rest of the hierarchy is available to sibling scripts.
		for body in landscape.find_children("GroundCollision", "StaticBody3D", true, false):
			terrain_bodies.append({"body":body,"parent":body.get_parent(),"owner":body.owner,"index":body.get_index()})
			body.owner = null
			body.get_parent().remove_child(body)
		terrain_task = Startup.begin("Terrain collision")
		var nature := landscape.get_node_or_null("NatureTiles")
		if nature != null:
			for tile in nature.get_children():
				scenery_tiles.append({"node":tile,"parent":nature,"owner":tile.owner})
				tile.owner = null
				nature.remove_child(tile)
			scenery_task = Startup.begin("Landscape scenery")
	phase_start = Time.get_ticks_usec()
	error = get_tree().change_scene_to_node(instance)
	if error != OK:
		saves.pending_slot = previous_slot
		get_tree().paused = false
		Startup.close(session)
		for entry in terrain_bodies: entry.body.free()
		for entry in scenery_tiles: entry.node.free()
		instance.free()
		queue_free()
		return false
	await get_tree().scene_changed
	timings["enter_ms"] = (Time.get_ticks_usec()-phase_start)/1000.0
	for entry in terrain_bodies:
		entry.body.collision_layer |= preload("res://world/suryagarh/tree_trunk_collision.gd").TERRAIN_SUPPORT_LAYER
		entry.parent.add_child(entry.body)
		entry.parent.move_child(entry.body,mini(entry.index,entry.parent.get_child_count()-1))
		entry.body.owner = entry.owner
		await Startup.checkpoint(self, "Preparing the landscape…")
	Startup.finish(terrain_task)
	for entry in scenery_tiles:
		entry.parent.add_child(entry.node)
		entry.node.owner = entry.owner
		await Startup.checkpoint(self, "Preparing the countryside…")
	Startup.finish(scenery_task)
	while not session.tasks.is_empty():
		await get_tree().process_frame
	# Save restoration/opening setup is deferred by the world. Wait for it, then draw.
	while saves.pending_slot >= 0:
		await get_tree().process_frame
	var world := get_tree().current_scene
	Startup.close(session)
	world.set_meta("startup_checkpoints", session.checkpoints)
	world.set_meta("startup_timings",timings)
	if world is Node3D: world.show()
	get_tree().paused = false
	var opening := world.get_node_or_null("OpeningSequence")
	# Do not let loading artwork hide the strike or consume cinematic time.
	if is_instance_valid(opening) and opening.state in ["prologue","night"]:
		opening.waiting_for_reveal = true
		opening.elapsed = 0.0
	status.text = "Entering India, 1857…" if slot == 0 else "Your journey is ready…"
	progress_bar.value = 100.0
	await _draw_frame()
	set_process_input(false)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reveal := create_tween()
	reveal.tween_property(panel, "modulate:a", 0.0, 0.65)
	await reveal.finished
	if is_instance_valid(opening): opening.waiting_for_reveal = false
	queue_free()
	return true

func _prepare_scene_scripts(path: String, scripts: Array[Script]) -> bool:
	# GDScript reports no ResourceLoader dependencies. Walk literal preloads
	# ourselves so compiling a script cannot synchronously pull in its geometry.
	var literals := RegEx.new()
	literals.compile("(?:preload|load)\\(\\s*[\"'](res://[^\"']+)[\"']|extends\\s+[\"'](res://[^\"']+)[\"']")
	var pending: Array[String] = [path]
	var seen: Dictionary = {}
	var script_paths: Array[String] = []
	var assets: Array[String] = []
	var visited := 0
	while not pending.is_empty():
		var current: String = pending.pop_back()
		if seen.has(current): continue
		seen[current] = true
		var dependencies: Array[String] = []
		if current.get_extension() == "gd":
			script_paths.append(current)
			for found in literals.search_all(FileAccess.get_file_as_string(current) if FileAccess.file_exists(current) else ""):
				dependencies.append(found.get_string(1) if not found.get_string(1).is_empty() else found.get_string(2))
		else:
			for dependency in ResourceLoader.get_dependencies(current):
				var fields := dependency.split("::")
				var source: String = fields[fields.size()-1]
				if source.begins_with("uid://"):
					var uid := ResourceUID.text_to_id(source)
					source = ResourceUID.get_id_path(uid) if ResourceUID.has_id(uid) else ""
				dependencies.append(source)
		for source in dependencies:
			if seen.has(source) or source.is_empty(): continue
			if source.get_extension() in ["gd", "tscn", "scn", "tres", "res"]:
				pending.append(source)
			elif source.get_extension() in ["glb", "gltf", "png", "jpg", "jpeg", "svg", "wav", "ogg", "mp3", "otf", "ttf", "gdshader"]:
				seen[source] = true
				assets.append(source)
		visited += 1
		if visited % 16 == 0: await get_tree().process_frame
	# Keep immutable imported assets alive through main-thread script compilation.
	var keep_assets: Array[Resource] = []
	status.text = "Preparing the journey’s surroundings…"
	var preparation_start := Time.get_ticks_usec()
	for first in range(0, assets.size(), 1):
		var batch: Array[String] = []
		for index in range(first, mini(first+1, assets.size())):
			var asset: String = assets[index]
			if not ResourceLoader.exists(asset): continue
			if ResourceLoader.has_cached(asset):
				keep_assets.append(ResourceLoader.load(asset))
			elif ResourceLoader.load_threaded_request(asset) == OK:
				batch.append(asset)
		while not batch.is_empty():
			for index in range(batch.size()-1, -1, -1):
				var state := ResourceLoader.load_threaded_get_status(batch[index])
				if state == ResourceLoader.THREAD_LOAD_LOADED:
					keep_assets.append(ResourceLoader.load_threaded_get(batch[index]))
					batch.remove_at(index)
				elif state != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					return false
			if not batch.is_empty(): await get_tree().process_frame
		progress_bar.value = 20.0 * mini(first+1, assets.size()) / maxf(1.0, assets.size())
		if Time.get_ticks_usec()-preparation_start > 4000:
			await get_tree().process_frame
			preparation_start = Time.get_ticks_usec()
	status.text = "Preparing your journey…"
	script_paths.reverse()
	var compilation_start := Time.get_ticks_usec()
	for index in script_paths.size():
		var script := ResourceLoader.load(script_paths[index], "GDScript") as Script
		if script == null: return false
		scripts.append(script)
		progress_bar.value = 20.0 + 5.0 * (index+1) / maxf(1.0, script_paths.size())
		if Time.get_ticks_usec()-compilation_start > 4000:
			await get_tree().process_frame
			compilation_start = Time.get_ticks_usec()
	return true
