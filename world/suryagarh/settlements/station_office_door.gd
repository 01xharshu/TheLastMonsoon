extends "res://objects/hinged_door.gd"
## Park paired leaves flat against the adjacent wall, keeping inquiry paths clear.

func _leaf_transform(index: int, amount: float) -> Transform3D:
	var side := -1.0 if index == 0 else 1.0
	var basis := Basis(Vector3.UP, side * amount * PI * swing_direction)
	var hinge := Vector3(side * width * .5, 0, 0)
	return Transform3D(basis, hinge + basis * Vector3(-side * width * .25, height * .5, 0))

func _apply_swing() -> void:
	for i in leaf_pivots.size():
		var side := -1.0 if i == 0 else 1.0
		leaf_pivots[i].rotation.y = side * swing * PI * swing_direction
		leaf_shapes[i].transform = _leaf_transform(i, swing)
