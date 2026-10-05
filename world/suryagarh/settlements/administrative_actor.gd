extends "res://characters/npcs/households/household_npc_actor.gd"
## Existing full MPFB bodies; personal tree owns seated writing and response.
var desk_at := Vector3.ZERO
var chair_at := Vector3.ZERO
var office_role := "clerk"
var working_phase := 0.0
var response_remaining := 0.0
var response_blend := 0.0
var office_ready := false
var near_elapsed := 0.0
var pose_updates := 0
var total_pose_usec := 0
var max_pose_usec := 0
var paper_target := Vector3.ZERO
var pen: MeshInstance3D
var player: Node3D
var cloth: Node3D
func _ready() -> void:
	movement_enabled = false
	foot_plant_enabled = false
	household_job = "OfficeClerk"
	super._ready()
	if _skeleton == null: return
	for kind in ["office_idle","office_write","office_attend"]:
		animation_player.get_animation_library("").add_animation(kind,office_clip(kind))
	var graph := animation_tree.tree_root as AnimationNodeBlendTree
	for kind in ["office_idle","office_write","office_attend"]:
		var clip := AnimationNodeAnimation.new()
		clip.animation = kind
		graph.add_node(kind,clip)
	graph.add_node("office_activity",AnimationNodeBlend2.new())
	graph.connect_node("office_activity",0,"office_idle")
	graph.connect_node("office_activity",1,"office_write")
	graph.add_node("office_response",AnimationNodeBlend2.new())
	graph.connect_node("office_response",0,"office_activity")
	graph.connect_node("office_response",1,"office_attend")
	graph.add_node("work_pose",AnimationNodeBlend2.new())
	graph.connect_node("work_pose",0,"turning")
	graph.connect_node("work_pose",1,"office_response")
	graph.disconnect_node("output",0)
	graph.connect_node("output",0,"work_pose")
	animation_tree.set("parameters/work_pose/blend_amount",1.0)
	pen = MeshInstance3D.new()
	pen.name = "HeldReedPen"
	var reed := CylinderMesh.new()
	reed.top_radius = .003
	reed.bottom_radius = .001
	reed.height = .1265
	reed.radial_segments = 8
	pen.mesh = reed
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.28,.18,.09)
	pen.material_override = material
	add_child(pen)
	for mesh: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		var label := mesh.name.to_lower()
		if "casualsuit" not in label and "elegantsuit" not in label: continue
		var fabric := ShaderMaterial.new()
		fabric.shader = preload("res://characters/npcs/households/fort_staff_fabric.gdshader")
		fabric.set_shader_parameter("cloth_color",Color(.70,.65,.54) if office_role != "judge" else Color(.075,.085,.09))
		fabric.set_shader_parameter("work_stains",.018)
		for surface in mesh.mesh.get_surface_count(): mesh.set_surface_override_material(surface,fabric)
	player = get_tree().current_scene.get_node_or_null("Player")
	office_ready = true
	_process(0.0)
	if office_role != "judge":
		cloth = preload("res://characters/npcs/households/household_drape.gd").new()
		cloth.name = "OfficeOuterDrape"
		add_child(cloth)
		cloth.configure(self)
func office_clip(kind: String) -> Animation:
	var clip := Animation.new()
	clip.length = 4.0
	clip.loop_mode = Animation.LOOP_LINEAR
	var path := str(get_path_to(_skeleton))
	for bone in _base_rotations:
		var index: int = _skeleton.find_bone(bone)
		if index < 0: continue
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track,NodePath(path+":"+str(bone)))
		for key in 9:
			var t := key*.5
			var angle := 0.0
			if str(bone).begins_with("thigh_"): angle = -1.5
			elif str(bone).begins_with("calf_"): angle = 1.5
			elif bone == "spine_02": angle = .13 if kind == "office_write" else .045
			elif bone == "head": angle = .17 if kind == "office_write" else .025*sin(t*TAU/4)
			elif str(bone).begins_with("upperarm_"): angle = -.35
			elif str(bone).begins_with("lowerarm_"): angle = -.9
			clip.rotation_track_insert_key(track,t,_base_rotations[bone]*Quaternion(_pitch_axes[bone],angle))
	return clip
func attend() -> void:
	response_remaining = 2.2
func _process(delta: float) -> void:
	if not office_ready or get_meta("dead",false) or get_meta("knocked_out",false): return
	near_elapsed += delta
	var distance := player.global_position.distance_to(global_position) if is_instance_valid(player) else 0.0
	if distance > 45 and near_elapsed < 1.0: return
	var step := near_elapsed
	near_elapsed = 0.0
	var start := Time.get_ticks_usec()
	working_phase += step
	response_remaining = maxf(0,response_remaining-step)
	response_blend = move_toward(response_blend,1.0 if response_remaining > 0 else 0.0,step/.3)
	var write := 1.0 if fmod(working_phase,10.0)<7.0 else 0.0
	if office_role == "judge": write = .4
	animation_tree.set("parameters/office_activity/blend_amount",write)
	animation_tree.set("parameters/office_response/blend_amount",response_blend)
	super._process(step)
	var hip := _skeleton.to_global(_skeleton.get_bone_global_pose(_skeleton.find_bone("pelvis")).origin)
	var seat := get_parent_node_3d().to_global(chair_at+Vector3(0,.60,.04))
	global_position += seat-hip
	for side in ["l","r"]:
		var ankle := get_parent_node_3d().to_global(chair_at+Vector3(-.16 if side=="l" else .16,.13,.48))
		foot_plant._solve(foot_plant.legs[side],_skeleton.to_local(ankle))
		set_meta("office_foot_error_"+side,_skeleton.to_global(_skeleton.get_bone_global_pose(_skeleton.find_bone("foot_"+side)).origin).distance_to(ankle))
	var stroke := Vector3(sin(working_phase*7)*.025,0,sin(working_phase*3.5)*.009)*write*(1-response_blend)
	paper_target = get_parent_node_3d().to_global(desk_at+Vector3(.45,.846,-.28)+stroke)
	var lift := .035*(1-write)+.045*response_blend
	solve_hand_contact("r",paper_target+Vector3(0,.12+lift,-.04))
	solve_hand_contact("l",get_parent_node_3d().to_global(desk_at+Vector3(-.48,.895,-.18)))
	set_grip("r",.48)
	set_grip("l",.13)
	var tip := paper_target+Vector3.UP*lift
	var palm := palm_world("r")
	pen.global_position = (palm+tip)*.5
	pen.global_basis = Basis(Quaternion(Vector3.UP,(palm-tip).normalized()))
	set_meta("office_pen_error",(pen.global_position-pen.global_basis.y*.06325).distance_to(tip))
	set_meta("office_seat_error",_skeleton.to_global(_skeleton.get_bone_global_pose(_skeleton.find_bone("pelvis")).origin).distance_to(seat))
	if cloth != null: cloth.update_pose()
	body_collider.force_update_transform()
	pose_updates += 1
	var cost := Time.get_ticks_usec()-start
	total_pose_usec += cost
	max_pose_usec = maxi(max_pose_usec,cost)
