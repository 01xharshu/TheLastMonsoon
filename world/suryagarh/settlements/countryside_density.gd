extends RefCounted
## Authored land occupation; shared by the offline bake and clearance validation.
const FIELD_SIZE := Vector2(42,30)
static func homes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	# Beyond the existing kitchen gardens: two facing rows and open lane ends.
	for z in [174.0,200.0,246.0,272.0,298.0,324.0]:
		for x in [-452.0,-476.0]:
			result.append({"p":Vector2(x,z),"yaw":PI*.5 if x < -464 else -PI*.5,"size":Vector2(10,8),"kind":"village"})
	for x in [-343.0,-319.0,-295.0,-271.0]:
		result.append({"p":Vector2(x,135),"yaw":0.0,"size":Vector2(10,8),"kind":"village"})
	for z in [80.0,-95.0,-240.0]:
		for offset in [Vector2(-14,-12),Vector2(14,-12),Vector2(-14,14)]:
			result.append({"p":Vector2(-570,z)+offset,"yaw":0.0,"size":Vector2(11,8),"kind":"farm"})
	return result
static func fields() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for z in [-260.0,-216.0,-172.0,-128.0,-84.0,-40.0,4.0,48.0,92.0,136.0]:
		for x in [-520.0,-632.0]:result.append(Vector2(x,z))
	for z in [194.0,238.0,282.0,326.0]:result.append(Vector2(-530,z))
	return result
static func lanes() -> Array[Array]:
	return [
		[Vector2(-464,155),Vector2(-464,342),Vector2(-374,342),Vector2(-374,312)],
		[Vector2(-464,155),Vector2(-374,155),Vector2(-374,162)],
		[Vector2(-355,152),Vector2(-250,152),Vector2(-250,174)],
		[Vector2(-570,-264),Vector2(-570,112),Vector2(-570,152),Vector2(-464,155)],
		[Vector2(-570,-284),Vector2(-440,-284),Vector2(-250,-284),Vector2(-250,-310)],
	]
static func clearance(p: Vector2) -> bool:
	for site in homes():
		var half_extent: Vector2 = site.size*.5+Vector2(4,4)
		if absf(sin(site.yaw))>.5:half_extent=Vector2(half_extent.y,half_extent.x)
		if Rect2(site.p-half_extent,half_extent*2).has_point(p):return true
	for center in fields():
		if Rect2(center-FIELD_SIZE*.5-Vector2.ONE,FIELD_SIZE+Vector2.ONE*2).has_point(p):return true
	for lane in lanes():
		for i in range(lane.size()-1):
			var a: Vector2=lane[i];var b:Vector2=lane[i+1]
			var t:=clampf((p-a).dot(b-a)/(b-a).length_squared(),0,1)
			if p.distance_to(a.lerp(b,t))<3:return true
	# Farm service courts and sheds.
	for z in [80.0,-95.0,-240.0]:
		if Rect2(Vector2(-592,z-26),Vector2(44,53)).has_point(p):return true
	return false

static func trees() -> Array[Vector2]:
	var result:Array[Vector2]=[]
	for center in [Vector2(-697,80),Vector2(-697,-95),Vector2(-697,-240)]:
		for row in 3:
			for col in 6:result.append(center+Vector2(-col*13+sin(row+col)*2,(row-1)*15+cos(col)*2))
	for row in 3:
		for col in 4:result.append(Vector2(-498-col*13,360+row*15)+Vector2(sin(row+col)*2,cos(col)*2))
	return result
