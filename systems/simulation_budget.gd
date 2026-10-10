extends RefCounted
## Shared conservative simulation tiers. State owners retain clocks and collision.
## No registry/static actor references: freed worlds cannot remain pinned here.
const NEAR_SQUARED := 6400.0
const FAR_SQUARED := 40000.0

static func interval(subject: Node3D, viewer: Node3D, essential := false) -> float:
	if essential or not is_instance_valid(viewer): return 0.0
	var squared := subject.global_position.distance_squared_to(viewer.global_position)
	if squared <= NEAR_SQUARED: return 0.0
	return 0.1 if squared <= FAR_SQUARED else 0.5
