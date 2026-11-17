extends "res://characters/npcs/households/household_npc_actor.gd"
## Stable personal identity; female fabric follows the actual retained MPFB rig.
var ground_height: Callable
var drape: RefCounted
var drape_age := 0.0
var run_blend := 0.0
var run_enabled := false
var run_phase := 0.0
var run_contact = preload("res://characters/npcs/indian/indian_run_contact.gd").new()
var adult_body_secondary:=preload("res://characters/npcs/adult_body_secondary_motion.gd").new()

func _ready() -> void:
	super._ready()
	if animation_tree != null:
		_install_run_branch()
	preload("res://characters/npcs/indian/population_skin_variation.gd").apply(self)
	for mesh:MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		if not str(mesh.name).begins_with("Street coherent cotton"):continue
		var cotton:=ShaderMaterial.new();cotton.shader=preload("res://characters/npcs/indian/street_cotton.gdshader")
		cotton.set_shader_parameter("cloth_color",Color.WHITE)
		mesh.material_override=cotton
	# Optional authored fit belongs to this complete body, and survives export.
	# Explicit world/actor overrides retain priority over asset calibration.
	for mesh:MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		if "MakeHuman_body_export_cutout" not in str(mesh.name):continue
		var fit:Dictionary=mesh.get_meta("extras",{})
		if bool(fit.get("adult_character",false)):set_meta("adult_character",true)
		if int(fit.get("street_body_fit_version",0))!=1:continue
		if not has_meta("sari_arm_clearance_rad"):
			set_meta("sari_arm_clearance_rad",clampf(float(fit.get("street_arm_clearance_rad",0.0)),0.0,.18))
		if not has_meta("sari_fit_body_waist"):
			set_meta("sari_fit_body_waist",bool(fit.get("street_fit_body_waist",false)))
	if OS.get_environment("TLM_STREET_SECONDARY")=="1":
		for mesh:MeshInstance3D in find_children("*","MeshInstance3D",true,false):
			if "MakeHuman_body_export_cutout" not in str(mesh.name):continue
			var secondary_fit:Dictionary=mesh.get_meta("extras",{})
			if int(secondary_fit.get("adult_secondary_version",0))!=1 or not bool(secondary_fit.get("adult_character",false)):continue
			set_meta("adult_character",true)
			adult_body_secondary.configure(self,_skeleton,float(secondary_fit.get("adult_secondary_breast_mass",1.0)),float(secondary_fit.get("adult_secondary_rear_mass",1.0)))
	if movement_profile == &"female" and _skeleton != null:
		drape = preload("res://characters/npcs/indian/river_sari_drape.gd").new(self, _skeleton,-.045,run_enabled)
		drape.update()
	elif _skeleton != null:
		drape=preload("res://characters/npcs/indian/indian_street_dhoti.gd").new(self,_skeleton)
		drape.update()

func _install_run_branch() -> void:
	var clip := Animation.new()
	clip.length = 0.72
	clip.loop_mode = Animation.LOOP_LINEAR
	var skeleton_path := str(get_path_to(_skeleton))
	for bone: String in _base_rotations:
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, NodePath(skeleton_path + ":" + bone))
		for frame in range(33):
			var fraction := frame / 32.0
			var phase := fposmod(fraction + (0.5 if bone.ends_with("_r") else 0.0), 1.0)
			var stride := cos(phase * TAU)
			var swing := sin(PI * clampf((phase - 0.38) / 0.62, 0.0, 1.0))
			var angle := 0.0
			match bone:
				"thigh_l", "thigh_r": angle = -0.52 * stride
				"calf_l", "calf_r": angle = 0.18 + 0.98 * swing
				"foot_l", "foot_r": angle = 0.28 * stride - 0.35 * swing
				"upperarm_l", "upperarm_r": angle = 0.29 * stride
				"lowerarm_l", "lowerarm_r": angle = -0.85 + 0.15 * stride
				"spine_02": angle = -0.12 + 0.035 * cos(2.0 * phase * TAU)
			clip.rotation_track_insert_key(track, fraction * clip.length, _base_rotations[bone] * Quaternion(_pitch_axes[bone], angle))
	animation_player.get_animation_library("").add_animation("street_run", clip)
	var graph := animation_tree.tree_root as AnimationNodeBlendTree
	var run := AnimationNodeAnimation.new()
	run.animation = &"street_run"
	graph.add_node("street_run", run)
	graph.add_node("street_run_seek", AnimationNodeTimeSeek.new())
	graph.connect_node("street_run_seek", 0, "street_run")
	graph.add_node("street_gait", AnimationNodeBlend2.new())
	graph.disconnect_node("turning", 0)
	graph.connect_node("street_gait", 0, "locomotion")
	graph.connect_node("street_gait", 1, "street_run_seek")
	graph.connect_node("turning", 0, "street_gait")
	animation_tree.set("parameters/street_gait/blend_amount", 0.0)
	run_contact.setup(self, _skeleton)
	run_enabled = true

func _set_animation(state: StringName, delta: float) -> void:
	var restore_plant := foot_plant_enabled
	if run_enabled:
		var running := state == &"walk" and travel_speed >= 2.4 and walk_direction >= 0.0
		run_blend = move_toward(run_blend, 1.0 if running else 0.0, maxf(delta, 0.0) / 0.18)
		animation_tree.set("parameters/street_gait/blend_amount", run_blend)
		animation_tree.set("parameters/street_run_seek/seek_request", run_phase * 0.72)
		run_phase = fposmod(run_phase + maxf(delta, 0.0) / 0.72, 1.0)
		if run_blend > 0.0:
			foot_plant_enabled = false
	super._set_animation(state, delta)
	foot_plant_enabled = restore_plant
	if run_enabled:
		if run_blend > 0.0 and restore_plant:
			run_contact.update_run(run_phase, run_blend)
		else:
			run_contact.clear()
	# Optional individual fit: keep the moving forearms clear of this person's
	# waist wrap. The animation tree still owns the underlying arm motion.
	var arm_clearance:=clampf(float(get_meta("sari_arm_clearance_rad",0.0)),0.0,.18)
	if movement_profile == &"female" and _skeleton != null and arm_clearance > 0.0:
		for side in ["l","r"]:
			var bone:=_skeleton.find_bone("upperarm_"+side)
			if bone < 0:continue
			var parent:=_skeleton.get_bone_parent(bone)
			if parent < 0:continue
			var axis:Vector3=(_skeleton.get_bone_global_pose(parent).basis.inverse()*Vector3.FORWARD).normalized()
			var direction:float=-1.0 if side=="l" else 1.0
			_skeleton.set_bone_pose_rotation(bone,Quaternion(axis,arm_clearance*direction)*_skeleton.get_bone_pose_rotation(bone))
		_skeleton.force_update_all_bone_transforms()
	adult_body_secondary.update(delta)
	if drape == null or DisplayServer.get_name()=="headless":return
	drape_age += delta
	var camera := get_viewport().get_camera_3d()
	var distance:float=global_position.distance_squared_to(camera.global_position) if camera!=null else INF
	var cadence:=0.0 if distance<400 else (.1 if distance<3600 else .5)
	if drape_age>=cadence:
		drape_age=0.0;drape.update()


func update_combat_clothing(action: String) -> void:
	if drape==null:return
	if drape.has_method("set_fallen"):
		drape.set_fallen(action in ["fall","down","rise"])
	drape.update()
