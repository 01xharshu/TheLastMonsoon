extends Node
## Mission-facing detention animation state; no arrest/crime trigger is invented here.
signal state_changed(state: String)
@onready var actor: CharacterBody3D = get_parent()
@onready var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
var mode := ""
var blend := 0.0
var releasing := false
var anchor := Transform3D.IDENTITY

func begin_detention(next_mode: String = "arrest") -> bool:
	if next_mode not in ["arrest", "waiting"]: return false
	if actor.inventory_ui.is_open() or actor.get_meta("weapon_wheel_open", false) or actor.get_meta("map_open", false) or actor.get_meta("scroll_open", false) or actor.get_meta("document_busy", false): return false
	if not actor.is_on_floor() or actor.is_swimming or actor.has_meta("mounted_vehicle") or actor.get_meta("climbing", false) or actor.get_meta("stealth_stance", "") != "" or actor.get_meta("rest_action", "") != "" or actor.get_meta("river_action", "") != "": return false
	if mode.is_empty(): anchor = actor.global_transform
	mode = next_mode
	releasing = false
	actor.velocity = Vector3.ZERO
	actor.set_meta("detention_action", mode)
	if visual.equipment != null:
		visual.equipment.set_swimming(true)
		visual.equipment.set_swimming(false)
	visual.slash_phase = -1.0
	visual.punch_phase = -1.0
	visual.kick_phase = -1.0
	actor.set_meta("interaction_reach", false)
	state_changed.emit(mode)
	return true

func wait_in_cell() -> bool:
	return begin_detention("waiting")

func release_detention() -> void:
	if mode.is_empty(): return
	releasing = true
	state_changed.emit("release")

func _process(delta: float) -> void:
	if mode.is_empty(): return
	blend = move_toward(blend, 0.0 if releasing else 1.0, delta / (0.85 if releasing else 1.15))
	actor.set_meta("detention_blend", smoothstep(0.0, 1.0, blend))
	if releasing and blend <= 0.0:
		mode = ""
		releasing = false
		actor.remove_meta("detention_action")
		actor.remove_meta("detention_blend")
		state_changed.emit("free")

func _physics_process(_delta: float) -> void:
	if mode.is_empty(): return
	actor.global_transform = anchor
	actor.velocity = Vector3.ZERO
