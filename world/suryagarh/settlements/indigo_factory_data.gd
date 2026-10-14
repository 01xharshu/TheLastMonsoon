extends RefCounted
## Fictional processing concern; coordinates are independent of terrain grading.
const CENTER := Vector2(-650,235)
const HALF := Vector2(34,25)
const ACCESS: Array[Vector2] = [Vector2(-650,210),Vector2(-650,172),Vector2(-570,156),Vector2(-464,155)]
const FIELD := Rect2(Vector2(-689,178),Vector2(28,12))
static func reserved(point: Vector2, margin := 0.0) -> bool:
	if Rect2(CENTER-HALF,HALF*2).grow(margin+2).has_point(point): return true
	if FIELD.grow(margin+1).has_point(point): return true
	for i in ACCESS.size()-1:
		var a: Vector2=ACCESS[i];var b: Vector2=ACCESS[i+1]
		var offset:=b-a
		if point.distance_to(a+offset*clampf((point-a).dot(offset)/offset.length_squared(),0,1))<3.0+margin: return true
	return false
