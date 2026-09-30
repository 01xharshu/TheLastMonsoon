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
const DURATION := 2.4

func _ready() -> void:
	actor = get_parent().get_parent()
	visual = actor.get_node("VisualRoot/CharacterVisual")
	pose_solver = actor.get_node("InteractionPoseComponent")
	process_priority = 11
	prop = MeshInstance3D.new()
	prop.name = "UsedItem"
	add_child(prop)
	prop.hide()
	get_parent().item_used.connect(start)

func start(action: String) -> void:
	if visual.skeleton == null: return
	kind = action
	elapsed = 0.0
	actor.set_meta("item_use",kind)
	previous_stowed = visual.equipment.stowed
	previous_weapon = visual.equipment.selected
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
	prop.show()

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
	var start: Vector3 = actor.global_position + visual.global_basis * Vector3(-0.25,0.9,0.22)
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
	target = palm.lerp(target,weight)
	var wrist: Vector3 = rig.to_local(target) - hand.basis * palm_offset
	pose_solver._solve_limb("upperarm_r","lowerarm_r","hand_r",wrist,Vector3(1,0,0.8))
	visual.equipment._grasp("r",0.4*weight)
	hand = rig.get_bone_global_pose(hand_index)
	var basis: Basis = rig.global_basis * hand.basis * visual.equipment.palm_axes["r"]
	if kind == "water": basis *= Basis(Vector3.RIGHT,-0.65 * weight)
	prop.global_transform = Transform3D(basis,rig.to_global(hand*palm_offset)+basis.z*0.025)
	prop.visible = not actor.first_person and elapsed < 2.15

func finish() -> void:
	kind = ""
	prop.hide()
	actor.set_meta("item_use","")
	visual.equipment._grasp("r",0.0)
	if visual.equipment.selected == previous_weapon and visual.equipment.stowed and not actor.is_swimming:
		visual.equipment.stowed = previous_stowed
		visual.equipment._refresh()
