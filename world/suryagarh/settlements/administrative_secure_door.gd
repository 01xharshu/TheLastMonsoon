extends "res://objects/hinged_door.gd"
## Strongroom remains locked from the public side; occupants retain egress.
func _time_changed(_day: int,_hour: int,_minute: int) -> void:
	locked = true
	_label()
func _label() -> void:
	interaction_text = "Treasury strongroom · staff access only" if not opened else "Close strongroom door"
