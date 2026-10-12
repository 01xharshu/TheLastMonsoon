extends RefCounted
## Editable chase geography; no mission triggers or autonomous simulation.
const BOUNDS := Rect2(Vector2(-815,350),Vector2(565,325))
const MAIN := [Vector2(-185,500),Vector2(-280,600),Vector2(-440,625),Vector2(-600,600),Vector2(-720,540),Vector2(-750,440),Vector2(-680,410),Vector2(-590,430),Vector2(-630,500),Vector2(-520,550),Vector2(-430,520),Vector2(-520,515),Vector2(-580,480),Vector2(-560,435),Vector2(-460,430),Vector2(-400,420),Vector2(-406,350),Vector2(-410,315),Vector2(-374,312)]
const GRADES := [5.0,5.0,6.0,9.0,14.0,20.0,26.0,31.0,36.0,40.0,42.0,39.0,36.0,32.0,24.0,19.0,18.0,12.0,7.2]
const RAVINE_BOUNDS := Rect2(Vector2(-864,369),Vector2(1040,32))
const BRIDGE := [Vector2(-400.8571429,410),Vector2(-405.1428571,360)]
const BRIDGE_GRADES := [18.8571429,18.1428571]
const SHORTCUTS := {}
const SHORTCUT_GRADES := {}

static func terrain(at: Vector2, original: float) -> float:
	var foundation := bank_foundation(at,original)
	if not BOUNDS.has_point(at): return foundation
	# Connected rounded knolls, rather than a rectangular raised platform.
	# The steeper rock faces are natural boundaries around the winding passes.
	var west := 51.0*exp(-pow((at.x+625.0)/170.0,4.0)-pow((at.y-497.0)/92.0,4.0))
	var east := 54.0*exp(-pow((at.x+445.0)/62.0,4.0)-pow((at.y-500.0)/57.0,4.0))
	var contour := maxf(west,east)
	contour*=1.0+.045*sin(at.x*.071)*cos(at.y*.053)
	return maxf(foundation,contour)

static func grade(at: Vector2, original: float) -> float:
	# End approaches also extend beyond the hill footprint to meet existing roads.
	if not BOUNDS.grow(75.0).has_point(at): return ravine(at,original)
	var result := original
	for identity: String in SHORTCUTS:
		result = grade_route(at,result,SHORTCUTS[identity],SHORTCUT_GRADES[identity],1.8,6.0)
	return ravine(at,grade_route(at,result,MAIN,GRADES,4.5,22.0))

static func grade_route(at: Vector2, original: float, route: Array, levels: Array, width: float, shoulder: float) -> float:
	var nearest := INF
	var target := original
	for i in route.size()-1:
		var a: Vector2=route[i]; var b: Vector2=route[i+1]
		var t := clampf((at-a).dot(b-a)/(b-a).length_squared(),0.0,1.0)
		var distance := at.distance_to(a.lerp(b,t))
		if distance < nearest:
			nearest=distance;target=lerpf(levels[i],levels[i+1],t)
	return lerpf(original,target,1.0-smoothstep(width,shoulder,nearest))

static func ravine(at: Vector2, original: float) -> float:
	var east_spur := Rect2(Vector2(-362,390),Vector2(24,115))
	var west_spur := Rect2(Vector2(-560,468),Vector2(222,24))
	var result := INF
	if RAVINE_BOUNDS.has_point(at):result=dry_cut(at,original,absf(at.y-385.0),16.0)
	if east_spur.has_point(at):result=minf(result,dry_cut(at,original,absf(at.x+350.0),12.0))
	if west_spur.has_point(at):result=minf(result,dry_cut(at,original,absf(at.y-480.0),12.0))
	return original if not is_finite(result) else result

static func dry_cut(at: Vector2, original: float, across: float, extent: float) -> float:
	# A dry lower service road lies in the rock cutting. Steep banks prevent
	# cutting straight across the hills; the upper route passes on the overbridge.
	# The bank is cut from the continuous road embankment, not a separate ridge.
	var crest := original
	var along := at.x if extent>12.0 or absf(at.y-480.0)<12.0 else at.y
	var shoulder := 7.0+(.5+.5*sin(along*.071))
	var deck := grade_route(at,-1000.0,BRIDGE,BRIDGE_GRADES,6.0,6.1)
	if deck>0.0:crest=minf(crest,deck-.4)
	if across<=5.0:return minf(original,4.0)
	if across<shoulder:return lerpf(4.0,crest,smoothstep(5.0,shoulder,across))
	return lerpf(crest,original,smoothstep(shoulder,extent,across))

static func bank_foundation(at: Vector2, original: float) -> float:
	# Broad earth shoulders connect the cutting to the road-bearing hill mass.
	# Keep outer terrain continuous rather than raising a narrow freestanding wall.
	var influence := 0.0
	if at.x>=-864.0 and at.x<=176.0:
		influence=maxf(influence,1.0-smoothstep(16.0,60.0,absf(at.y-385.0)))
	if at.y>=390.0 and at.y<=505.0:
		influence=maxf(influence,1.0-smoothstep(12.0,56.0,absf(at.x+350.0)))
	if at.x>=-560.0 and at.x<=-338.0:
		influence=maxf(influence,1.0-smoothstep(12.0,56.0,absf(at.y-480.0)))
	var surveyed := 23.0+2.0*sin(at.x*.035)*sin(at.y*.031)
	return lerpf(original,maxf(original,surveyed),influence)
