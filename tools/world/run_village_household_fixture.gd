extends SceneTree
func _initialize() -> void:_load.call_deferred()
func _load() -> void:
	root.add_child(load("res://tools/world/validate_village_household_variety.gd").new())
