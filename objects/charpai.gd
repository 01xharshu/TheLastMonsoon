extends Interactable

@export_category("Sleeping")
@export var sleep_hours: float = 8.0
@export var energy_restore_per_hour: float = 12.5
@export var minimum_tiredness_required: float = 5.0

var resting := false

func _ready() -> void:
	interaction_text = "Sleep %s Hours" % str(sleep_hours)

func interact(player: CharacterBody3D) -> void:
	if resting or player.get_meta("rest_action", "") != "": return
	var survival := player.get_node_or_null("SurvivalComponent") as SurvivalComponent
	var game_time := player.get_parent().get_node_or_null("GameTimeSystem") as GameTimeSystem
	if survival == null or game_time == null:
		push_warning("Charpai requires SurvivalComponent and GameTimeSystem")
		return
	if survival.max_energy - survival.energy < minimum_tiredness_required: return
	_run_sleep(player, survival, game_time)

func _run_sleep(player: CharacterBody3D, survival: SurvivalComponent, game_time: GameTimeSystem) -> void:
	resting = true
	var start_transform := player.global_transform
	var saved_layer := player.collision_layer
	var saved_mask := player.collision_mask
	var visual := player.get_node_or_null("VisualRoot/CharacterVisual")
	if visual != null and visual.equipment != null:
		visual.equipment.set_swimming(true)
		visual.equipment.set_swimming(false)
	player.velocity = Vector3.ZERO
	player.collision_layer = 0
	player.collision_mask = 0
	player.global_position = to_global(Vector3(0, 0.83, 0))
	player.global_basis = global_basis
	player.set_meta("rest_action", "sleep")
	player.set_meta("rest_progress", 0.0)
	var settle := create_tween()
	settle.tween_method(func(value: float) -> void: player.set_meta("rest_progress", value), 0.0, 1.0, 1.0)
	await settle.finished
	var shade := CanvasLayer.new()
	shade.layer = 100
	player.add_child(shade)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(black)
	var fade_out := create_tween()
	fade_out.tween_property(black, "color:a", 1.0, 0.6)
	await fade_out.finished
	set_meta("sleep_fade_covered", true)
	game_time.advance_hours(sleep_hours)
	survival.restore_energy(sleep_hours * energy_restore_per_hour)
	await get_tree().create_timer(0.25).timeout
	var fade_in := create_tween()
	fade_in.tween_property(black, "color:a", 0.0, 0.7)
	await fade_in.finished
	shade.queue_free()
	var rise := create_tween()
	rise.tween_method(func(value: float) -> void: player.set_meta("rest_progress", value), 1.0, 0.0, 0.7)
	await rise.finished
	player.global_transform = start_transform
	player.collision_layer = saved_layer
	player.collision_mask = saved_mask
	player.set_meta("rest_action", "")
	player.set_meta("rest_progress", 0.0)
	remove_meta("sleep_fade_covered")
	resting = false
