extends RefCounted
## Dedicated jump choreography: no alternating pull poses inside a leap or catch.
static func configure(graph: AnimationNodeBlendTree) -> void:
	var sequence := AnimationNodeBlendSpace1D.new()
	sequence.min_space = 0.0
	sequence.max_space = 5.0
	for entry in [{"clip":"reach","at":0.0},{"clip":"hang","at":1.0},{"clip":"load","at":2.0},{"clip":"leap","at":3.0},{"clip":"catch","at":4.0},{"clip":"hang","at":5.0}]:
		var pose := AnimationNodeAnimation.new()
		pose.animation = "motion/climb_"+entry.clip
		sequence.add_blend_point(pose,entry.at,-1,entry.clip+str(int(entry.at)))
	graph.add_node("climb_sequence",sequence)
	graph.add_node("climb_selector",AnimationNodeBlend2.new())
	graph.connect_node("climb_selector",0,"climb_pose")
	graph.connect_node("climb_selector",1,"climb_sequence")

static func position(phase: String, clock: float) -> float:
	match phase:
		"catch": return smoothstep(0.0,.32,clock)
		"hang": return 1.0
		"load": return 1.0+smoothstep(0.0,.24,clock)
		"flight": return 2.0+2.0*smoothstep(0.0,.58,clock)
		"settle": return 4.0+smoothstep(0.0,.26,clock)
	return -1.0

static func update(tree: AnimationTree, phase: String, clock: float) -> void:
	var blend_position := position(phase,clock)
	tree.set("parameters/climb_selector/blend_amount",1.0 if blend_position >= 0.0 else 0.0)
	if blend_position >= 0.0: tree.set("parameters/climb_sequence/blend_position",blend_position)
