extends "res://characters/npcs/households/household_npc_actor.gd"
## Independent locomotion and contact on the existing MPFB thana rig.
var duty_state := "idle"
var detainee: CharacterBody3D
var hand_contact_error := 0.0
var strike_progress := -1.0
var strike_contact_error := INF
const ALARM_GESTURE_SECONDS := 1.45
const DialogueExpression = preload("res://story/dialogue_expression.gd")
var station_alarm_pose := false
var station_alarm_face: RefCounted
var station_alarm_owns_face := false
var records_age := 0.0
var records_seated := false
var records_pen: MeshInstance3D
var records_elapsed := 0.0
var records_defence: Node
func _ready() -> void:
	movement_enabled = false
	household_job = "Police"
	super._ready()
	add_to_group("thana_officers")
	if get_meta("station_records_duty",false):
		records_defence=get_node_or_null("SelfDefence")
		create_records_pen()
	for mesh in find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var original:=mesh.get_active_material(surface) as StandardMaterial3D
			if original==null:continue
			if "police puttee cloth" in original.resource_name.to_lower():
				var wraps:=ShaderMaterial.new()
				wraps.shader=preload("res://characters/npcs/thana/thana_puttee.gdshader")
				wraps.set_shader_parameter("cloth_color",original.albedo_color)
				mesh.set_surface_override_material(surface,wraps)
				continue
			if "sikh uncut beard" in original.resource_name.to_lower():
				var hair:=ShaderMaterial.new()
				hair.shader=preload("res://characters/npcs/thana/thana_beard.gdshader")
				hair.set_shader_parameter("hair_color",original.albedo_color)
				mesh.set_surface_override_material(surface,hair)
				continue
			if not ("police drab cotton" in original.resource_name.to_lower() or "police tan fittings" in original.resource_name.to_lower()):continue
			var cloth:=ShaderMaterial.new()
			cloth.shader=preload("res://characters/npcs/households/household_cloth.gdshader")
			cloth.set_shader_parameter("cloth_color",original.albedo_color)
			mesh.set_surface_override_material(surface,cloth)
func create_records_pen() -> void:
	records_pen=MeshInstance3D.new()
	records_pen.name="ClerkWritingReed"
	var reed:=CylinderMesh.new()
	reed.top_radius=.003
	reed.bottom_radius=.001
	reed.height=.16
	reed.radial_segments=6
	records_pen.mesh=reed
	var reed_material:=StandardMaterial3D.new()
	reed_material.albedo_color=Color(.27,.17,.07)
	records_pen.material_override=reed_material
	records_pen.rotation=Vector3(-.4,0,-.25)
	records_pen.hide()
	add_child(records_pen)

func _process(delta: float) -> void:
	station_alarm_pose = false
	var alarm_remaining := (int(get_meta("station_alarm_gesture_until",0))-Time.get_ticks_msec())*.001
	var incapacitated: bool = get_meta("dead",false) or get_meta("knocked_out",false) or animation_tree == null
	var signaling: bool = not incapacitated and alarm_remaining > 0.0 and duty_state in ["idle","guard","patrol","fight"] and (not is_instance_valid(detainee) or duty_state=="fight")
	if not signaling and station_alarm_face != null:
		if station_alarm_owns_face:
			station_alarm_face.restore()
		else:
			station_alarm_face.apply(0.0,0.0)
		station_alarm_face = null
	if incapacitated: return
	if get_meta("station_records_duty",false):
		if not is_instance_valid(records_defence):records_defence=get_node_or_null("SelfDefence")
		records_elapsed+=delta
		var cadence: float=preload("res://systems/simulation_budget.gd").interval(self,get_viewport().get_camera_3d(),get_meta("defending",false) or (records_defence!=null and records_defence.active))
		if records_elapsed<cadence:return
		delta=records_elapsed
		records_elapsed=0.0
	_set_animation(&"walk" if travel_speed>.02 else &"idle",delta)
	if get_meta("station_records_duty",false):
		var defence: Node=records_defence
		var interrupted: bool=get_meta("defending",false) or get_meta("police_engaged",false) or (defence!=null and defence.active) or duty_state!="idle"
		var post: Vector3=get_meta("station_records_post",position)
		if not interrupted and position.distance_to(post)<.25:
			if not is_instance_valid(records_pen):create_records_pen()
			records_age+=delta
			records_seated=true
			_skeleton.set_bone_pose_position(foot_plant.pelvis,foot_plant.pelvis_position+foot_plant.pelvis_down*.43)
			pose_inquiry_desk(-.43)
			var page:=Vector3(-.28,.945,.74)
			page.x+=sin(records_age*4.2)*.035
			page.z+=fmod(records_age,2.4)*.016
			solve_hand_contact("r",to_global(page))
			set_grip("r",.38)
			records_pen.position=page+Vector3(.02,.07,-.025)
			records_pen.show()
			var body_shape: CollisionShape3D=body_collider.get_node("BodyShape")
			body_shape.shape.height=1.1
			body_shape.position.y=.65
			return
		if records_seated:
			records_seated=false
			if is_instance_valid(records_pen):records_pen.hide()
			foot_plant.reset_pose()
			var body_shape: CollisionShape3D=body_collider.get_node("BodyShape")
			body_shape.shape.height=1.7
			body_shape.position.y=.9
	if get_meta("inquiry_at_desk",false):
		pose_inquiry_desk()
		return
	apply_fight_pose()
	if signaling:
		if station_alarm_face == null:
			var defence := get_node_or_null("SelfDefence")
			station_alarm_face = defence.face if defence != null else null
			station_alarm_owns_face = station_alarm_face == null
			if station_alarm_owns_face:
				station_alarm_face = DialogueExpression.new()
				station_alarm_face.configure(self)
		var alarm_age := ALARM_GESTURE_SECONDS - alarm_remaining
		var surprise := smoothstep(0.0,.16,alarm_age)*(1.0-smoothstep(.24,.68,alarm_age))
		var shout := DialogueExpression.speech_weight(alarm_age,ALARM_GESTURE_SECONDS)
		station_alarm_face.apply(surprise*.8,0.0,shout*.45,shout)
		var incident: Vector3 = to_local(get_meta("station_alarm_target",global_position+global_basis.z))
		var extension := smoothstep(0.0,.24,alarm_remaining)*(1.0-smoothstep(1.23,1.45,alarm_remaining))
		var reach := Vector3(clampf(incident.x,-.35,.46),1.53,.54)
		solve_hand_contact("l",to_global(Vector3(.24,1.07,.23).lerp(reach,extension)))
		set_grip("l",.08)
		station_alarm_pose = true

	if is_instance_valid(detainee) and duty_state in ["restraint","escort"]:
		if duty_state=="restraint":
			_skeleton.set_bone_pose_rotation(_bones["spine_02"],_base_rotations["spine_02"]*Quaternion(_pitch_axes["spine_02"],.74))
			_skeleton.force_update_all_bone_transforms()
		var visual: Node3D = detainee.get_node("VisualRoot/CharacterVisual")
		var rig: Skeleton3D = visual.skeleton
		var bone: String = "hand_l" if duty_state=="restraint" else "upperarm_l"
		var target := rig.to_global(rig.get_bone_global_pose(rig.find_bone(bone)).origin)
		if duty_state=="escort": target += detainee.global_basis*Vector3(.04,-.10,0)
		solve_hand_contact("r",target)
		set_grip("r",.25)
		hand_contact_error = palm_world("r").distance_to(target)
func pose_inquiry_desk(height_offset:=0.0) -> void:
	for side in ["l","r"]:
		for joint in [["thigh_",-1.32],["calf_",1.54],["foot_",0.0]]:
			var bone: String = joint[0]+side
			if _bones.has(bone):
				_skeleton.set_bone_pose_rotation(_bones[bone],_base_rotations[bone]*Quaternion(_pitch_axes[bone],joint[1]))
	_skeleton.force_update_all_bone_transforms()
	for side in ["l","r"]:
		var across := .18 if side=="l" else -.18
		if foot_plant.legs.has(side):
			var ankle := to_global(Vector3(across,.53+height_offset,.43))
			var leg: Array = foot_plant.legs[side]
			foot_plant._solve(leg,_skeleton.to_local(ankle))
			var foot: int = leg[2]
			var parent := _skeleton.get_bone_global_pose(_skeleton.get_bone_parent(foot)).basis
			var flat := _skeleton.get_bone_global_rest(foot).basis
			_skeleton.set_bone_pose_rotation(foot,(parent.inverse()*flat).orthonormalized().get_rotation_quaternion())
		solve_hand_contact(side,to_global(Vector3(across,1.36+height_offset,.60)))
		set_grip(side,.13)

func strike_target() -> Vector3:
	var outward := global_position-detainee.global_position
	outward.y = 0.0
	if outward.length_squared() < .001: outward = -global_basis.z
	# Target the near torso surface, rather than the centre of the body.
	return detainee.global_position + Vector3.UP*.35 + outward.normalized()*.25

func apply_fight_pose() -> void:
	if duty_state != "fight" or not is_instance_valid(detainee) or strike_progress < 0.0: return
	var extension := sin(clampf(strike_progress,0,1)*PI)
	_skeleton.set_bone_pose_rotation(_bones["spine_02"],_base_rotations["spine_02"]*Quaternion(_pitch_axes["spine_02"],.12*extension))
	_skeleton.force_update_all_bone_transforms()
	solve_hand_contact("l",global_position+global_basis*Vector3(.22,1.25,.30))
	set_grip("l",1.0)
	var guard := global_position + global_basis*Vector3(-.22,1.2,.25)
	var hit := strike_target()
	solve_hand_contact("r",guard.lerp(hit,extension))
	set_grip("r",1.0)
	strike_contact_error = palm_world("r").distance_to(hit)

func take_damage(amount: float) -> void:
	super.take_damage(amount)
