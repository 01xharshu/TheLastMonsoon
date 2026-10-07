extends Node
## Cosmetic use sequence after successful transactions; follows the current native rig.
var actor: CharacterBody3D
var visual: Node3D
var pose_solver: Node
var prop: MeshInstance3D
var kind := ""
var elapsed := 0.0
var previous_stowed := true
var previous_weapon := -1
var carried_pouch: Node3D
var pouch_start := Transform3D.IDENTITY
var start_palm := Vector3.ZERO
var start_hand_basis := Basis.IDENTITY
const DURATION := 2.4

func _ready() -> void:
	actor = get_parent().get_parent()
	visual = actor.get_node("VisualRoot/CharacterVisual")
	pose_solver = actor.get_node("InteractionPoseComponent")
	process_priority = 12
	carried_pouch = actor.get_node("VisualRoot/EquipmentVisuals/WaterBagVisual")
	prop = MeshInstance3D.new()
	prop.name = "UsedItem"
	add_child(prop)
	prop.hide()
	get_parent().item_used.connect(start)

func start(action: String) -> void:
	if visual.skeleton == null: return
	WorldAudio.play_at("water_drink" if action=="water" else "cloth",actor.global_position)
	kind = action
	elapsed = 0.0
	actor.set_meta("item_use",kind)
	previous_stowed = visual.equipment.stowed
	previous_weapon = visual.equipment.selected
	var hand: Transform3D = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_r"))
	start_palm = visual.skeleton.to_global(hand * visual.equipment.palm_offsets["r"])
	start_hand_basis = visual.skeleton.global_basis * hand.basis
	pouch_start = carried_pouch.global_transform
	if kind == "water": carried_pouch.held = true
	visual.equipment.stowed = true
	visual.equipment._refresh()
	var surface := StandardMaterial3D.new()
	surface.roughness = 0.95
	if kind == "roti":
		var bread := SphereMesh.new()
		bread.radius = 0.075
		bread.height = 0.018
		prop.mesh = bread
		surface.albedo_color = Color(0.69,0.48,0.25)
	elif kind == "water":
		var pouch := SphereMesh.new()
		pouch.radius = 0.065
		pouch.height = 0.19
		prop.mesh = pouch
		surface.albedo_color = Color(0.30,0.18,0.09)
	else:
		var dressing := CylinderMesh.new()
		dressing.top_radius = 0.04
		dressing.bottom_radius = 0.04
		dressing.height = 0.08
		prop.mesh = dressing
		surface.albedo_color = Color(0.81,0.77,0.65)
	prop.material_override = surface
	prop.visible = kind != "water"

func _process(delta: float) -> void:
	if kind.is_empty(): return
	if actor.health <= 0.0 or actor.is_swimming or actor.get_meta("climbing",false) or actor.get_meta("rest_action","") != "" or (actor.has_meta("mounted_vehicle") and actor.get_meta("mounted_vehicle") != null) or visual.equipment.selected != previous_weapon:
		finish()
		return
	elapsed += delta
	if elapsed >= DURATION:
		finish()
		return
	var rig: Skeleton3D = visual.skeleton
	var weight := smoothstep(0.0,0.4,elapsed) * (1.0-smoothstep(1.9,DURATION,elapsed))
	var hand_index := rig.find_bone("hand_r")
	var hand: Transform3D = rig.get_bone_global_pose(hand_index)
	var palm_offset: Vector3 = visual.equipment.palm_offsets["r"]
	var palm: Vector3 = rig.to_global(hand * palm_offset)
	var start: Vector3 = start_palm
	if kind == "water": start = pouch_start * (carried_pouch.pouch.transform * carried_pouch.pouch.get_node("RightGrip").position)
	var destination: Vector3
	if kind == "bandage":
		visual.pose("upperarm_l", Vector3(-0.8,0,-0.35),weight)
		visual.pose("lowerarm_l", Vector3(-1.3,0,0),weight)
		var forearm: Transform3D = rig.get_bone_global_pose(rig.find_bone("lowerarm_l"))
		var left_hand: Transform3D = rig.get_bone_global_pose(rig.find_bone("hand_l"))
		destination = rig.to_global(forearm.origin.lerp(left_hand.origin,0.65))
		var turn := maxf(0.0,elapsed-0.5) * TAU * 1.8
		destination += visual.global_basis * Vector3(0,cos(turn)*0.045,sin(turn)*0.045)
	else:
		var head: Transform3D = rig.get_bone_global_pose(rig.find_bone("head"))
		destination = rig.to_global(head.origin) + visual.global_basis * Vector3(0,-0.09,0.16)
		visual.pose("head", Vector3(-0.06 if kind == "water" else sin(elapsed*TAU*3)*0.025,0,0),weight)
	var target: Vector3 = start.lerp(destination,smoothstep(0.2,0.9,elapsed))
	target = start_palm.lerp(target,weight)
	if kind != "bandage": target = pose_solver._outside_pickup_clothes(target)
	var desired_basis: Basis = start_hand_basis
	if kind == "water":
		# The wrist carries a vertical pouch by its neck, then gently tips it.
		desired_basis = start_hand_basis * Basis(Vector3.RIGHT,-0.35*weight)
	pose_solver._set_world_basis("hand_r",desired_basis)
	hand = rig.get_bone_global_pose(hand_index)
	var wrist: Vector3 = rig.to_local(target) - hand.basis * palm_offset
	for solve_pass in 3:
		pose_solver._solve_limb("upperarm_r","lowerarm_r","hand_r",wrist,Vector3(1,0,0.8))
		pose_solver._set_world_basis("hand_r",desired_basis)
		hand = rig.get_bone_global_pose(hand_index)
		wrist = rig.to_local(target) - hand.basis * palm_offset
	visual.equipment._grasp("r",0.4*weight)
	hand = rig.get_bone_global_pose(hand_index)
	var basis: Basis = rig.global_basis * hand.basis * visual.equipment.palm_axes["r"]
	if kind == "water":
		var lift := smoothstep(.15,.75,elapsed)*(1.0-smoothstep(1.7,DURATION,elapsed))
		var pouch_basis: Basis = visual.global_basis * Basis(Vector3.RIGHT,-.55*lift)
		var grip: Vector3 = carried_pouch.pouch.transform * carried_pouch.pouch.get_node("RightGrip").position
		carried_pouch.global_transform = Transform3D(pouch_basis,rig.to_global(hand*palm_offset)-pouch_basis*grip)
	prop.global_transform = Transform3D(basis,rig.to_global(hand*palm_offset)+basis.z*0.025)
	prop.visible = kind != "water" and not actor.first_person and elapsed < 2.15

func finish() -> void:
	kind = ""
	carried_pouch.held = false
	prop.hide()
	actor.set_meta("item_use","")
	visual.equipment._grasp("r",0.0)
	if visual.equipment.selected == previous_weapon and visual.equipment.stowed and not actor.is_swimming:
		visual.equipment.stowed = previous_stowed
		visual.equipment._refresh()
