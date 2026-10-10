extends "res://characters/npcs/indian/indian_npc_candidate.gd"
## Reuses the adult MPFB rig. Action/blocking study, not approved cloth/contact.
const Contact = preload("res://characters/npcs/indian/river_contact_solver.gd")
var river_cloth_meshes: Array[MeshInstance3D] = []
var previous_cloth_keys: Dictionary = {}
var river_key_indices: Dictionary = {}
var river_mesh_key_indices: Dictionary = {}
var travel_slope := 0.0
var sari_drape: RefCounted
const CLOTH_TIMES = preload("res://characters/npcs/indian/river_cloth_timeline.gd").TIMES
const WALK_SAMPLES := 48
const WALK_STRIDE := .60
var foot_rest: Dictionary = {}
var hand_errors: Dictionary = {}
var foot_errors: Dictionary = {}
var mouth_height := 0.0
var skeleton: Skeleton3D
var pot: MeshInstance3D
var cloth: MeshInstance3D
var elapsed := 0.0
var member_index := 0
var water_full := false
var delivered := false
var action := "home"
var travel_speed := .4
var travel_gait_time := 0.0
var travel_override := false
var travel_position := Vector3.ZERO
var travel_direction := Vector3.FORWARD
var ground_height: Callable
var water_level := .01
var home := Vector3.ZERO
var bank := Vector3.ZERO
const STAGES := ["depart", "arrive", "lower_pot", "fill", "lift_pot", "wash", "sit_down", "talk", "stand_up", "pickup_pot", "return", "deliver", "home"]
const DURATIONS := [10.0, 2.0, 3.0, 5.0, 3.0, 12.0, 3.0, 10.0, 3.0, 4.0, 10.0, 3.0, 4.0]

func _ready() -> void:
	candidate_slug = "village_woman"
	_load_river_motion()
	_personal_appearance()
	skeleton = find_child("*", true, false) as Skeleton3D
	for node in find_children("*", "Skeleton3D", true, false):
		skeleton = node as Skeleton3D
		break
	for mesh in find_children("*", "MeshInstance3D", true, false):
		if str(mesh.name) in ["Fitted cotton upper base","Wrapped sari lower drape","Sari lower border","Woven sari pallu over blouse","Opaque fitted bra and thong foundation"]:
			river_cloth_meshes.append(mesh)
			var mesh_keys := {}
			for key in mesh.mesh.get_blend_shape_count(): mesh_keys[str(mesh.mesh.get_blend_shape_name(key))]=key
			river_mesh_key_indices[mesh.get_instance_id()]=mesh_keys
			if river_key_indices.is_empty() and mesh.mesh.get_blend_shape_count()>0:
				for key in mesh.mesh.get_blend_shape_count():
					river_key_indices[str(mesh.mesh.get_blend_shape_name(key))]=key
	var figure := animation_player.get_node(animation_player.root_node) as Node3D
	figure.rotation.y = PI
	for side in ["l", "r"]:
		foot_rest[side] = global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_rest(skeleton.find_bone("foot_" + side))
	sari_drape=preload("res://characters/npcs/indian/river_sari_drape.gd").new(self,skeleton)
	pot = MeshInstance3D.new()
	pot.name = "EarthenWaterPot"
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.36, .15, .075)
	material.roughness = .92
	pot.material_override = material
	add_child(pot)
	# Continuous clay profile with a real open mouth and inner wall.
	var profile := [Vector2(-.16,0), Vector2(-.16,.065), Vector2(-.13,.11), Vector2(-.07,.15), Vector2(.02,.16), Vector2(.1,.13), Vector2(.145,.075), Vector2(.195,.065), Vector2(.20,.07), Vector2(.20,.055), Vector2(.16,.05), Vector2(.14,.06), Vector2(.1,.11), Vector2(.02,.14), Vector2(-.07,.13), Vector2(-.12,.075), Vector2(-.13,0)]
	var clay := SurfaceTool.new()
	clay.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in profile.size()-1:
		for segment in 32:
			for pair in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var point: Vector2 = profile[ring+pair.x]
				var angle := TAU*float(segment+pair.y)/32.0
				clay.add_vertex(Vector3(sin(angle)*point.y,point.x,cos(angle)*point.y))
	clay.generate_normals()
	pot.mesh = clay.commit()
	cloth = MeshInstance3D.new()
	cloth.name = "LaundryStudyCloth"
	var cloth_mesh := PlaneMesh.new()
	cloth_mesh.size = Vector2(.45, .35)
	cloth.mesh = cloth_mesh
	var cotton := StandardMaterial3D.new()
	cotton.albedo_color = Color(.66, .58, .44)
	cotton.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.material_override = cotton
	add_child(cloth)

func _personal_appearance()->void:
	var identity:=member_index%3
	var saris:=[Color(.36,.18,.12),Color(.19,.29,.25),Color(.32,.20,.29)]
	var blouses:=[Color(.20,.25,.28),Color(.37,.29,.18),Color(.25,.21,.18)]
	var skin_tints:=[Color(.78,.60,.46),Color(.65,.45,.32),Color(.88,.69,.52)]
	for mesh:MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		var label:=str(mesh.name)
		var skin:bool="MakeHuman_body" in label
		var garment:bool=label in ["Fitted cotton upper base","Wrapped sari lower drape","Sari lower border","Woven sari pallu over blouse"]
		if not skin and not garment:continue
		for surface in mesh.mesh.get_surface_count():
			var original:=mesh.get_active_material(surface) as StandardMaterial3D
			if original==null:continue
			var material:=original.duplicate() as StandardMaterial3D
			if skin:material.albedo_color*=skin_tints[identity]
			elif label=="Fitted cotton upper base":material.albedo_color=blouses[identity]
			elif label=="Sari lower border":material.albedo_color=saris[identity].lightened(.18)
			else:material.albedo_color=saris[identity]
			mesh.set_surface_override_material(surface,material)

func _process(delta: float) -> void:
	tick_routine(delta)

func sample(time: float) -> void:
	elapsed = maxf(time, 0.0)
	_evaluate(0.0)

func tick_routine(delta: float) -> void:
	elapsed += maxf(delta, 0.0)
	_evaluate(delta)

func _evaluate(delta: float) -> void:
	var time := elapsed
	var stage := STAGES.size() - 1
	for index in DURATIONS.size():
		if time < DURATIONS[index]:
			stage = index
			break
		if index < DURATIONS.size() - 1:
			time -= DURATIONS[index]
	var blend := clampf(time / float(DURATIONS[stage]), 0.0, 1.0)
	action = STAGES[stage]
	water_full = stage >= 4
	delivered = action == "home" or (action == "deliver" and blend >= .5)
	walking = action in ["depart", "return"] and (not travel_override or travel_speed>0.0)
	if is_zero_approx(delta): locomotion_blend=1.0 if walking else 0.0
	playback_rate = travel_speed*1.2*.6/WALK_STRIDE if travel_override and walking else .9
	animation_tree.set("parameters/idle_seek/seek_request",fposmod(elapsed,animation_player.get_animation("idle").length))
	if walking and not travel_override:
		animation_tree.set("parameters/walk_seek/seek_request",fposmod(elapsed/1.2,1.0)*animation_player.get_animation("walk").length)
	if travel_override and walking:
		animation_tree.set("parameters/walk_seek/seek_request",_walk_phase()*animation_player.get_animation("walk").length)
	if skeleton != null:
		skeleton.reset_bone_poses()
	super.step_motion(maxf(delta, .000001))
	if skeleton == null:
		return
	var seated := 0.0
	if action == "sit_down": seated = smoothstep(0.0, 1.0, blend)
	if action == "talk": seated = 1.0
	if action == "stand_up": seated = 1.0 - smoothstep(0.0, 1.0, blend)
	var pickup_progress := minf(blend/.75, 1.0)
	var crouch := 0.0
	if action == "lower_pot": crouch = smoothstep(0.0, 1.0, blend)
	if action == "fill": crouch = 1.0
	if action == "wash": crouch = smoothstep(0.0, 1.0, minf(time/1.5, 1.0))
	if action == "sit_down": crouch = 1.0-seated
	if action == "lift_pot": crouch = 1.0-smoothstep(0.0, 1.0, blend)
	global_position = home.lerp(bank, blend) if action == "depart" else bank
	if action in ["return", "deliver", "home"]: global_position = bank.lerp(home, blend) if action == "return" else home
	if travel_override and action in ["depart","return"]: global_position = travel_position
	var figure := animation_player.get_node(animation_player.root_node) as Node3D
	if action == "deliver": crouch = sin(PI*blend)
	if action == "pickup_pot": crouch = sin(PI*pickup_progress)
	var walking_drop := .13 if travel_override else .07
	var gait_bob := 0.0
	var gait_sway := 0.0
	if travel_override and locomotion_blend>0.0:
		gait_bob=.012*(1.0-cos(_walk_phase()*TAU*2.0))
		gait_sway=.010*sin(_walk_phase()*TAU)
	travel_slope=0.0
	if walking and travel_override and ground_height.is_valid():
		var ahead := global_position+global_basis*Vector3(0,0,-.35)
		var behind := global_position+global_basis*Vector3(0,0,.35)
		travel_slope=(float(ground_height.call(ahead.x,ahead.z))-float(ground_height.call(behind.x,behind.z)))/.7
		var high_ground := global_position.y
		var low_ground := global_position.y
		for probe in [ahead,behind,global_position+global_basis*Vector3(-.2,0,0),global_position+global_basis*Vector3(.2,0,0)]:
			var height: float=ground_height.call(probe.x,probe.z)
			high_ground=maxf(high_ground,height);low_ground=minf(low_ground,height)
		walking_drop+=maxf(high_ground-global_position.y,global_position.y-low_ground)
	figure.position.y = -.64 * crouch - .695 * seated - walking_drop*locomotion_blend+gait_bob*locomotion_blend
	figure.position.x=gait_sway*locomotion_blend
	figure.position.z = -.18*crouch
	var facing := home-bank if action in ["return", "deliver", "home"] else bank-home
	if walking and travel_override: facing = travel_direction
	var desired_heading := atan2(-facing.x, -facing.z)
	if not walking and action not in ["deliver","home"]: desired_heading=-PI/2.0 if travel_override else desired_heading
	rotation.y = lerp_angle(rotation.y,desired_heading,1.0-exp(-delta*6.0)) if walking and delta>0.0 else desired_heading
	if action == "pickup_pot": rotation.y += PI*smoothstep(0.0, 1.0, maxf((blend-.75)*4.0, 0.0))
	if seated > 0.0: rotation.y += (.35 if member_index == 0 else -.35) * seated
	_rotate_bone("spine_01", Vector3.RIGHT, .40*crouch + .05*seated)
	_rotate_bone("spine_02", Vector3.RIGHT, .25*crouch)
	_rotate_bone("neck_01", Vector3.RIGHT, -.20*crouch)
	if walking and travel_override:
		_rotate_bone("neck_01",Vector3.UP,.07*sin(elapsed*.12+member_index*2.0))
	# Plant ankle targets while lowering/raising the pelvis; knees bend forward.
	foot_errors.clear()
	for side in ["l", "r"]:
		var rest: Transform3D = foot_rest[side]
		var target := global_transform * rest.origin
		if walking:
			var phase := fposmod(elapsed/1.2 + (.5 if side == "r" else 0.0), 1.0)
			var stride := .288 if not travel_override else WALK_STRIDE
			# Match the planted-foot sweep to actual forward speed.
			if travel_override:
				phase=fposmod(_walk_phase()+(.5 if side=="r" else 0.0),1.0)
			if travel_override and travel_speed<=0.0: stride=0.0
			var z := lerpf(-stride*.5, stride*.5, phase/.6) if phase < .6 else lerpf(stride*.5, -stride*.5, smoothstep(0.0, 1.0, (phase-.6)/.4))
			var lift := 0.0 if phase < .6 else (.055 if stride>0.0 else 0.0)*sin(PI*(phase-.6)/.4)
			target += global_basis * Vector3(0, lift, z)
		target += global_basis * Vector3((-1.0 if side=="l" else 1.0)*(.06*crouch+.08*seated), 0, -.10*crouch-.36*seated)
		if ground_height.is_valid(): target.y += float(ground_height.call(target.x,target.z))-global_position.y
		var pole := global_position + global_basis * Vector3(rest.origin.x+(-1.0 if side=="l" else 1.0)*.12*(crouch+seated), .35, -1.0)
		foot_errors[side] = Contact.reach(skeleton, "thigh_"+side, "calf_"+side, "foot_"+side, target, pole)
		var foot_basis := global_basis*rest.basis
		if ground_height.is_valid():
			var hx := float(ground_height.call(target.x-.06,target.z))-float(ground_height.call(target.x+.06,target.z))
			var hz := float(ground_height.call(target.x,target.z-.06))-float(ground_height.call(target.x,target.z+.06))
			foot_basis=Basis(Quaternion(Vector3.UP,Vector3(hx,.12,hz).normalized()))*foot_basis
		Contact.orient(skeleton, "foot_"+side, foot_basis)
	# Pot follows a continuous, externally defined path; hands reach its handles.
	var carry := Vector3(gait_sway*.35*locomotion_blend, .88+gait_bob*.7*locomotion_blend, -.30)
	var dip := Vector3(0, .09+water_level-.01-bank.y, -.52)
	var pot_local := carry
	var tilt := 0.0
	if action == "lower_pot":
		pot_local = carry.lerp(dip, smoothstep(0.0, 1.0, blend))
		tilt = deg_to_rad(115.0)*smoothstep(0.0, 1.0, blend)
	if action == "fill":
		pot_local = dip
		tilt = deg_to_rad(115.0)
	if action == "lift_pot":
		pot_local = dip.lerp(carry, smoothstep(0.0, 1.0, blend))
		tilt = deg_to_rad(115.0)*(1.0-smoothstep(0.0, 1.0, blend))
	if action in ["sit_down", "talk", "stand_up"]: pot_local = Vector3(.22, .17, -.32)
	if action == "wash": pot_local = carry.lerp(Vector3(.22, .17, -.32), smoothstep(0.0, 1.0, minf(time/1.5, 1.0)))
	if action == "deliver": pot_local = carry.lerp(Vector3(0, .17, -.32), smoothstep(0.0, 1.0, minf(blend*2.0, 1.0)))
	if action == "home": pot_local = Vector3(0, .17, -.32)
	pot.visible = true
	var bank_rotation := -PI/2.0 if travel_override else atan2(-(bank-home).x, -(bank-home).z)
	var parked := Transform3D(Basis(Vector3.UP, bank_rotation), bank) * Transform3D(Basis.IDENTITY, Vector3(.22, .17, -.32))
	pot.global_transform = global_transform * Transform3D(Basis(Vector3.RIGHT, -tilt), pot_local)
	if action in ["sit_down", "talk", "stand_up"]: pot.global_transform = parked
	if action == "pickup_pot":
		pot.global_position = parked.origin.lerp(global_transform*carry, smoothstep(0.0, 1.0, maxf((pickup_progress-.5)*2.0, 0.0)))
	mouth_height = (pot.global_transform * Vector3(0, .20, 0)).y
	hand_errors.clear()
	var holding := action in ["depart", "arrive", "lower_pot", "fill", "lift_pot", "return", "deliver"]
	if action == "deliver" and blend >= .5: holding = false
	if action == "wash" and time < 1.5: holding = true
	if action == "pickup_pot": holding = true
	if holding:
		for side in ["l", "r"]:
			var sign_side := -1.0 if side == "l" else 1.0
			var grip := pot.global_transform * Vector3(sign_side*.185, 0, 0)
			if action == "pickup_pot" and pickup_progress < .45:
				var neutral := skeleton.global_transform*Contact.point(skeleton, "hand_"+side)
				grip = neutral.lerp(grip, smoothstep(0.0, 1.0, pickup_progress/.45))
				# Before grasp, approach within the unstretched arm envelope.
				var shoulder := skeleton.global_transform*Contact.point(skeleton, "upperarm_"+side)
				var elbow := skeleton.global_transform*Contact.point(skeleton, "lowerarm_"+side)
				var wrist := skeleton.global_transform*Contact.point(skeleton, "hand_"+side)
				var limit := shoulder.distance_to(elbow)+elbow.distance_to(wrist)-.001
				grip = shoulder+(grip-shoulder).limit_length(limit)
			_reach_hand(side, grip)
			_orient_grip(side, Vector3.DOWN)
			_curl_fingers(side, .45)
	# Wash has readable rub, rinse and wring phases and shares exact cloth targets.
	cloth.visible = action == "wash" and time >= 1.5
	if action == "wash" and time >= 1.5:
		var wash_phase := fposmod(time, 6.0)
		var local := Vector3(0, .16, -.46)
		var wring := 0.0
		if wash_phase < 2.0: local.z += .04*sin(time*TAU)
		elif wash_phase < 4.0:
			local = local.lerp(Vector3(0, .09, -.52), sin(PI*(wash_phase-2.0)/2.0))
		else:
			wring = sin(PI*(wash_phase-4.0)/2.0)
			local = local.lerp(Vector3(0, .44, -.38), wring)
		cloth.global_transform = global_transform * Transform3D(Basis.IDENTITY, local)
		_shape_laundry(wring, time)
		for side in ["l", "r"]:
			var grip := cloth.global_transform * Vector3(-.18 if side == "l" else .18, .015, 0)
			_reach_hand(side, grip)
			_orient_grip(side, global_basis*Vector3(1 if side == "l" else -1, 0, 0))
			_curl_fingers(side, .32)
	if seated > 0.0:
		_rotate_bone("neck_01", Vector3.UP, .12*sin(time*.7+member_index))
		var speaking := action == "talk" and int(time/2.5)%3 == 0
		for side in ["l", "r"]:
			var gesture := .10*sin(time*2.2) if speaking else 0.0
			var target := global_transform * Vector3(-.23 if side == "l" else .23, .38-.08*seated+.55*(1.0-seated-crouch)+gesture, -.34)
			_reach_hand(side, target)
	if sari_drape!=null:sari_drape.update()
	_apply_river_cloth()
	pot.set_meta("contains_water", water_full)
	set_meta("river_action", action)

func _shape_laundry(wring: float, time: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		for j in 4:
			for offset in [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(0,1), Vector2i(1,0), Vector2i(1,1)]:
				var u := float(i+offset.x)/10.0
				var v := float(j+offset.y)/4.0
				var x := lerpf(-.18, .18, u)
				var z := lerpf(-.11, .11, v)*(1.0-.55*wring)
				var angle := wring*sin(time*3.0)*(u*2.0-1.0)*1.4
				var sag := -.04*sin(PI*u)
				surface.set_uv(Vector2(u,v))
				surface.add_vertex(Vector3(x, sag+sin(angle)*z, cos(angle)*z))
	surface.generate_normals()
	cloth.mesh = surface.commit()

func _reach_hand(side: String, target: Vector3) -> void:
	var shoulder := skeleton.global_transform * Contact.point(skeleton, "upperarm_"+side)
	var pole := shoulder + global_basis*Vector3(-.3 if side == "l" else .3, -.18, .08)
	hand_errors[side] = Contact.reach(skeleton, "upperarm_"+side, "lowerarm_"+side, "hand_"+side, target, pole)

func _orient_grip(side: String, direction: Vector3) -> void:
	var hand := skeleton.find_bone("hand_"+side)
	var from := Contact.point(skeleton, "middle_01_"+side)-Contact.point(skeleton, "hand_"+side)
	var to := skeleton.global_basis.inverse()*direction
	Contact.aim(skeleton, hand, from, to)

func _curl_fingers(side: String, amount: float) -> void:
	for finger in ["index", "middle", "ring", "pinky"]:
		for joint in ["01", "02", "03"]:
			var bone := skeleton.find_bone(finger+"_"+joint+"_"+side)
			skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone)*Quaternion(Vector3.RIGHT, amount))

func _rotate_bone(label: String, axis: Vector3, angle: float) -> void:
	var index := skeleton.find_bone(label)
	if index < 0: return
	var local_axis := skeleton.get_bone_global_rest(index).basis.inverse() * axis
	skeleton.set_bone_pose_rotation(index, skeleton.get_bone_pose_rotation(index) * Quaternion(local_axis.normalized(), angle))

func _load_river_motion() -> void:
	var path := "res://characters/npcs/motion/river_woman/river_woman_rigged_candidate.glb"
	var figure := preload("res://characters/human_scene.gd").instantiate(path)
	if figure == null:
		push_error("Cannot load Indian motion candidate: " + path)
		return
	add_child(figure)
	animation_player = figure.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player == null:
		push_error("Missing candidate AnimationPlayer")
		return
	for clip_name in ["idle", "walk"]:
		if not animation_player.has_animation(clip_name):
			push_error("Missing candidate clip: " + clip_name)
			return
		animation_player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
	animation_player.stop()
	animation_tree = AnimationTree.new()
	animation_tree.name = "PersonalAnimationTree"
	add_child(animation_tree)
	animation_tree.anim_player = animation_tree.get_path_to(animation_player)
	animation_tree.root_node = animation_tree.get_path_to(animation_player.get_node(animation_player.root_node))
	var graph := AnimationNodeBlendTree.new()
	for clip_name in ["idle", "walk"]:
		var node := AnimationNodeAnimation.new()
		node.animation = clip_name
		graph.add_node(clip_name, node)
	graph.add_node("walk_rate", AnimationNodeTimeScale.new())
	graph.add_node("walk_seek",AnimationNodeTimeSeek.new())
	graph.add_node("idle_seek",AnimationNodeTimeSeek.new())
	graph.add_node("locomotion", AnimationNodeBlend2.new())
	graph.connect_node("walk_seek",0,"walk")
	graph.connect_node("walk_rate", 0, "walk_seek")
	graph.connect_node("idle_seek",0,"idle")
	graph.connect_node("locomotion", 0, "idle_seek")
	graph.connect_node("locomotion", 1, "walk_rate")
	graph.connect_node("output", 0, "locomotion")
	animation_tree.tree_root = graph
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation_tree.active = true
	step_motion(0.0)


func _walk_phase() -> float:
	return fposmod(travel_gait_time*.4*.6/WALK_STRIDE+member_index*.17,1.0)

func _apply_river_cloth() -> void:
	if river_cloth_meshes.is_empty(): return
	var weights: Dictionary = {}
	if walking and travel_override and river_key_indices.has("River walk 1 00"):
		var phase := _walk_phase()*WALK_SAMPLES
		var lower := int(floorf(phase))%WALK_SAMPLES
		var upper := (lower+1)%WALK_SAMPLES
		var slope := clampf(travel_slope/.225+2.0,0.0,4.0)
		var slope_lower := int(floorf(slope))
		var slope_upper := mini(slope_lower+1,4)
		for bank in [slope_lower,slope_upper]:
			var slope_weight := 1.0 if slope_lower==slope_upper else 1.0-slope+slope_lower if bank==slope_lower else slope-slope_lower
			for frame in [lower,upper]:
				var frame_weight := 1.0-phase+lower if frame==lower else phase-lower
				var key_name := "River walk %d %02d"%[bank,frame]
				weights[key_name]=slope_weight*frame_weight
	else:
		var cloth_time := elapsed
		if travel_override and travel_speed<=0.0 and action in ["depart","return"]:
			# Waiting companions carry their pots with neutral feet, not a walk pose.
			cloth_time=minf(12.0,10.0+fposmod(elapsed-10.0,animation_player.get_animation("idle").length))
		var low := 0
		var high: int = CLOTH_TIMES.size()-1
		while low<high:
			var middle: int = (low+high+1)/2
			if CLOTH_TIMES[middle]<=cloth_time: low=middle
			else: high=middle-1
		var lower := low
		var upper := mini(lower+1,CLOTH_TIMES.size()-1)
		var fraction: float=0.0 if lower==upper else clampf((cloth_time-CLOTH_TIMES[lower])/(CLOTH_TIMES[upper]-CLOTH_TIMES[lower]),0.0,1.0)
		for frame in [lower,upper]:
			var key_name := "River cloth %03d"%frame
			weights[key_name]=1.0 if lower==upper else 1.0-fraction if frame==lower else fraction

	for mesh in river_cloth_meshes:
		var mesh_keys: Dictionary=river_mesh_key_indices.get(mesh.get_instance_id(),{})
		for old in previous_cloth_keys:
			if not weights.has(old) and mesh_keys.has(old): mesh.set_blend_shape_value(mesh_keys[old],0.0)
		for key in weights:
			if mesh_keys.has(key): mesh.set_blend_shape_value(mesh_keys[key],weights[key])
	previous_cloth_keys=weights
