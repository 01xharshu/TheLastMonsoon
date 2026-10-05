extends "res://world/suryagarh/settlements/settlement_builder.gd"
## Focused fixture: same cantonment construction, without unrelated districts.
func _ready() -> void:
	plaster = material(Color(.76,.70,.56))
	ochre = material(Color(.55,.40,.24))
	brick = material(Color(.44,.24,.16),true)
	wood = material(Color(.23,.13,.07))
	tile = material(Color(.43,.19,.105),true)
	stone = material(Color(.42,.40,.33),true)
	iron = material(Color(.13,.14,.13))
	preload("res://world/suryagarh/settlements/cantonment.gd").new().build(self)
	preload("res://world/suryagarh/settlements/administrative_district.gd").new().build(self)
