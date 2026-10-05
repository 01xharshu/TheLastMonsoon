extends RefCounted
## Local support survey for sloped rock tops and separate broken masonry pieces.
var actor: CharacterBody3D
var edge := Vector3.ZERO
var normal := Vector3.ZERO
var tangent := Vector3.ZERO
var landing := Vector3.ZERO
var highest := 0.0

func probe(point: Vector3, reference_y: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x,reference_y+.85,point.z),Vector3(point.x,reference_y-.85,point.z))
	query.exclude = [actor.get_rid()]
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y<.65: return {}
	return hit

func survey(body: CharacterBody3D, face: Dictionary) -> bool:
	actor = body
	normal = Vector3(face.normal.x,0,face.normal.z).normalized()
	if normal.length_squared()<.5: return false
	tangent = Vector3.UP.cross(normal).normalized()
	var feet_y: float = actor.global_position.y-.9
	var reference_y: float = minf(feet_y+1.5,face.position.y+.65)
	var lip_hits: Array[Vector3] = []
	for side in [-1.0,1.0]:
		var hit := probe(face.position-normal*.22+tangent*side*.32,reference_y)
		if hit.is_empty(): return false
		var point: Vector3 = hit.position
		if point.y-feet_y<.55 or point.y-feet_y>2.15: return false
		lip_hits.append(point)
	if absf(lip_hits[0].y-lip_hits[1].y)>.55: return false
	highest = maxf(lip_hits[0].y,lip_hits[1].y)
	edge = Vector3(face.position.x,highest,face.position.z)
	# Survey the whole capsule footprint. One successful ray can hide a hole.
	for depth in [.65,.9,1.2]:
		var center: Vector3 = edge-normal*depth
		var heights: Array[float] = []
		for offset in [Vector3.ZERO,tangent*.32,-tangent*.32,normal*.32,-normal*.32]:
			var support := probe(center+offset,highest)
			if support.is_empty(): break
			heights.append(support.position.y)
		if heights.size()!=5: continue
		var upper: float = heights.max()
		var lower: float = heights.min()
		if upper-lower>.48 or absf(upper-highest)>.70: continue
		landing = Vector3(center.x,upper+.94,center.z)
		var shape := PhysicsShapeQueryParameters3D.new()
		shape.shape = actor.get_node("CollisionShape3D").shape
		shape.transform = Transform3D(Basis.IDENTITY,landing)
		shape.exclude = [actor.get_rid()]
		if actor.get_world_3d().direct_space_state.intersect_shape(shape,1).is_empty(): return true
	return false

func contact(point: Vector3) -> Dictionary:
	return probe(point,highest)
