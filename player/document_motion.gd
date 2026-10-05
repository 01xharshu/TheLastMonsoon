extends Node3D
## Applies the cosmetic document motion after ordinary locomotion.
var actor: CharacterBody3D
var visual: Node3D
var solver: Node
var sheet: MeshInstance3D
var rollers: Array[MeshInstance3D] = []
var elapsed := 0.0
var closing := false
var active := false
var notice: Node3D
var previous_stowed := true
var ink: Label3D
var open_amount := 0.0
var lift_amount := 0.0
var closing_amount := 0.0
var closing_lift := 0.0
var reach_amount := 0.0
var closing_reach := 0.0
var detached := false
var edge_targets: Dictionary = {}

func _ready() -> void:
	actor = get_parent()
	visual = actor.get_node("VisualRoot/CharacterVisual")
	solver = actor.get_node("InteractionPoseComponent")
	process_priority = 20
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.78,.69,.49)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = .95
	sheet = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(.38,.003,.30)
	sheet.mesh = mesh
	sheet.material_override = material
	add_child(sheet)
	ink = Label3D.new()
	ink.font = preload("res://assets/ui/fonts/MFBOldstyle-Regular.otf")
	ink.font_size = 22
	ink.pixel_size = .0009
	ink.outline_size = 0
	ink.modulate = Color(.20,.14,.08)
	ink.rotation.x = -PI*.5
	ink.position.y = .003
	sheet.add_child(ink)
	for side in [-1,1]:
		var roller := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = .020
		cylinder.bottom_radius = .020
		cylinder.height = .34
		cylinder.radial_segments = 12
		roller.mesh = cylinder
		roller.rotation.z = PI*.5
		roller.position.z = side*.15
		roller.material_override = material
		sheet.add_child(roller)
		rollers.append(roller)
	hide()
	set_process(false)

func begin(source: Node3D = null) -> void:
	notice = source
	elapsed = 0.0
	(sheet.mesh as BoxMesh).size.z = .50 if is_instance_valid(source) else .30
	sheet.scale = Vector3.ONE
	open_amount = 0.0
	lift_amount = 0.0
	detached = false
	reach_amount = 0.0
	ink.text = source.headline+"\nDISTRICT OFFICE\n────────" if is_instance_valid(source) else "ARJUN\nTRAVELLER'S RECORD\n────────"
	closing = false
	active = true
	previous_stowed = visual.equipment.stowed
	visual.equipment.stowed = true
	visual.equipment._refresh()
	actor.set_meta("document_busy",true)
	show()
	set_process(true)

func finish() -> void:
	if not active: return
	closing_amount = open_amount
	closing_lift = lift_amount
	closing_reach = reach_amount
	closing = true
	elapsed = 0.0

func _exit_tree() -> void:
	if is_instance_valid(notice): notice.paper.show()

func _process(delta: float) -> void:
	if visual.skeleton == null: return
	elapsed += delta
	if is_instance_valid(notice) and not closing:
		var facing := notice.global_position-actor.global_position
		actor.visual_root.global_rotation.y = lerp_angle(actor.visual_root.global_rotation.y,atan2(facing.x,facing.z),1.0-exp(-10.0*delta))
	var t := smoothstep(0.0,.85,elapsed)
	var weight := closing_amount*(1.0-t) if closing else t
	open_amount = weight
	if closing and elapsed >= .85:
		if is_instance_valid(notice):
			notice.paper.show()
			notice.reading = false
		visual.equipment.stowed = previous_stowed
		visual.equipment._refresh()
		actor.set_meta("document_busy",false)
		actor.set_meta("scroll_open",false)
		active = false
		hide()
		set_process(false)
		return
	var reading := visual.to_global(Vector3(0,.24,.31))
	var shoulders: Vector3 = (visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("upperarm_l")).origin + visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("upperarm_r")).origin)*.5
	reading.y = visual.skeleton.to_global(shoulders).y - .18
	var at := reading
	var basis := visual.global_basis * Basis(Vector3.RIGHT,-.40)
	if is_instance_valid(notice):
		var lift := smoothstep(.25,.85,elapsed) if not closing else closing_lift*(1.0-smoothstep(0.0,.60,elapsed))
		lift_amount = lift
		at = notice.global_position.lerp(reading,lift)
		# Posted paper is vertical; held paper is tilted toward the eyes.
		var wall_basis := notice.global_basis * Basis(Vector3.RIGHT,PI*.5)
		basis = wall_basis.orthonormalized().slerp(basis.orthonormalized(),lift)
		if not closing and elapsed >= .25:
			detached = true
			notice.paper.hide()
		if closing and detached and elapsed >= .60:
			notice.paper.show()
			detached = false
		sheet.visible = detached
	else:
		sheet.visible = true
		at = visual.to_global(Vector3(0,-.10,.22)).lerp(reading,weight)
		var length := lerpf(.035,.30,weight)
		(sheet.mesh as BoxMesh).size.z = length
		for i in rollers.size(): rollers[i].position.z = (-1.0 if i == 0 else 1.0)*length*.5
	global_transform = Transform3D(basis,at)
	for roller in rollers: roller.visible = not is_instance_valid(notice)
	ink.visible = weight >= .72 if not is_instance_valid(notice) else detached
	visual.pose("head",Vector3(.28,0,0),weight)
	reach_amount = closing_reach*(1.0-smoothstep(.60,.85,elapsed)) if closing else minf(elapsed/.25,1.0)
	var hand_weight := reach_amount if is_instance_valid(notice) else weight
	for side in ["l","r"]:
		var sign_x := -1.0 if side == "l" else 1.0
		var grip := Vector3(sign_x*.18,0,0) if is_instance_valid(notice) else Vector3(sign_x*.13,.012,sign_x*(sheet.mesh as BoxMesh).size.z*.5)
		var desired := at + basis * grip
		edge_targets[side] = desired
		var rig: Skeleton3D = visual.skeleton
		var hand_index: int = rig.find_bone("hand_"+side)
		var hand: Transform3D = rig.get_bone_global_pose(hand_index)
		var palm: Vector3 = rig.to_global(hand * visual.equipment.palm_offsets[side])
		desired = palm.lerp(desired,hand_weight)
		# Define palm orientation from the paper, then solve elbow and wrist in rig space.
		# Fingers follow the sheet, with the thumb side facing upward.
		var forward: Vector3 = basis.z
		var normal: Vector3 = basis.y
		var across: Vector3 = forward.cross(normal).normalized()
		var grip_basis: Basis = Basis(across,forward,normal) * visual.equipment.palm_axes[side].inverse()
		var initial_basis: Basis = rig.global_basis * hand.basis
		grip_basis = initial_basis.orthonormalized().slerp(grip_basis.orthonormalized(), hand_weight)
		var pole: Vector3 = rig.global_basis.inverse() * (visual.global_basis * Vector3(sign_x*.7,-.45,-.4))
		for i in 4:
			solver._set_world_basis("hand_"+side,grip_basis)
			hand = rig.get_bone_global_pose(hand_index)
			var target: Vector3 = rig.to_local(desired)-hand.basis*visual.equipment.palm_offsets[side]
			solver._solve_limb("upperarm_"+side,"lowerarm_"+side,"hand_"+side,target,pole)
			solver._set_world_basis("hand_"+side,grip_basis)
		visual.equipment._grasp(side,.40*hand_weight)
