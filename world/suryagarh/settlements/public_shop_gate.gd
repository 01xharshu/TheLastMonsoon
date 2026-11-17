extends "res://objects/hinged_door.gd"
## Open public doorway. Older saves may contain a closed or locked gate state.

func interaction_available() -> bool:
	return false

func restore_state(_value: bool) -> void:
	manual_locked = false
	locked = false
	swing_direction = -1.0
	super.restore_state(true)
