extends RefCounted
## Drive the draft animation from movement accepted by collision.
var previous := Vector3.INF

func sample(cart: Node3D, commanded: float, delta: float) -> float:
	var position := cart.global_position
	var prior := previous
	previous = position
	if delta <= 0.0 or absf(commanded) < .01 or not prior.is_finite():
		return 0.0
	var displacement := position-prior
	displacement.y = 0
	if displacement.length() > maxf(2.0, absf(commanded)*delta*3.0):
		return 0.0
	return absf(displacement.dot(-cart.global_basis.z))/delta
