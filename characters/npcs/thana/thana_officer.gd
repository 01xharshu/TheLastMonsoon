extends "res://characters/npcs/households/household_npc_actor.gd"
## Independent locomotion and contact on the existing MPFB thana rig.
var duty_state := "idle"
var detainee: CharacterBody3D
var hand_contact_error := 0.0
func _ready() -> void:
	movement_enabled = false
	household_job = "Police"
	super._ready()
	add_to_group("thana_officers")
	for mesh in find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var original:=mesh.get_active_material(surface) as StandardMaterial3D
			if original==null:continue
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
func _process(delta: float) -> void:
	if get_meta("dead",false) or get_meta("knocked_out",false) or animation_tree == null: return
	_set_animation(&"walk" if travel_speed>.02 else &"idle",delta)
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
func take_damage(amount: float) -> void:
	super.take_damage(amount)
