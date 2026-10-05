extends RefCounted
## Field-level math only: no per-plant physics, invisibility or crop height invention.
static func cover_sample(field: Node3D, feet: Vector3, eye_height: float, observer: Vector3) -> float:
	var local := field.to_local(feet)
	var record: Dictionary = field.get_meta("crop_cover", {})
	# Existing kitchen beds are short, sparse plants; they offer little prone cover.
	var bounds: Rect2 = record.get("bounds", Rect2(-4, -2.2, 8, 4.4))
	var height: float = maxf(0.0, float(record.get("height", .55)))
	var density: float = clampf(float(record.get("density", .10)), 0.0, 1.0)
	if not bounds.has_point(Vector2(local.x, local.z)) or absf(local.y) > .5: return 0.0
	if height <= eye_height: return 0.0
	var depth := minf(minf(local.x-bounds.position.x, bounds.end.x-local.x), minf(local.z-bounds.position.y, bounds.end.y-local.z))
	var edge := clampf(depth/.8, 0.0, 1.0)
	var distance := Vector2(observer.x-feet.x,observer.z-feet.z).length()
	var nearby := clampf((distance-2.5)/5.0, 0.0, 1.0)
	var elevated := clampf(1.0-maxf(0.0, observer.y-feet.y-height)/maxf(distance,1.0)*2.5, 0.0, 1.0)
	return clampf((height-eye_height)/maxf(height,.1)*density*edge*nearby*elevated, 0.0, .9)
