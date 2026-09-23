extends StaticBody3D
## A reachable rope cut drops the high cloth; each flag can award fame once.
var cut := false
var cloth: Node3D
var rope: Node3D

func _ready() -> void:
	add_to_group("cuttable_flags")

func bind_visual() -> void:
	cloth = find_child("eic_flag_cloth", true, false)
	rope = find_child("eic_flagpole_rope", true, false)

func cut_flag() -> bool:
	if cut: return false
	cut = true
	if rope: rope.hide()
	if cloth:
		var fall := create_tween()
		fall.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.tween_property(cloth, "position:y", cloth.position.y - 3.0, 0.75)
		fall.parallel().tween_property(cloth, "rotation:z", 0.12, 0.75)
	return true
