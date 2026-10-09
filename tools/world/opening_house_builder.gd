extends "res://world/suryagarh/settlements/settlement_builder.gd"
## Use the game's actual house construction without spawning the whole district.
func _ready() -> void:
	plaster = material(Color(.76,.70,.56))
	ochre = material(Color(.55,.40,.24))
	brick = material(Color(.44,.24,.16),true)
	wood = material(Color(.23,.13,.07))
	tile = material(Color(.43,.19,.105),true)
	stone = material(Color(.42,.40,.33),true)
	iron = material(Color(.13,.14,.13))
