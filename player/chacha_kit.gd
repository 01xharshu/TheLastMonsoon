extends Node
## Additional family weapons; ownership uses the normal saved inventory.
var actor: CharacterBody3D
var gear: Node3D
var spear: Node3D
var active := false
var cooldown := 0.0
var thrust := -1.0
var rest := Transform3D.IDENTITY
var landed := false
func _ready() -> void:
	process_priority=10
	actor=get_parent();gear=actor.get_node("VisualRoot/CharacterVisual").equipment
	spear=gear.attach_at_rest("hand_r",preload("res://environment/weapons/period_spear/period_spear.glb"),Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,-.8,0)),"ChachaSpear")
	rest=spear.transform;spear.hide()
func equip(id: String) -> void:
	active=id=="spear"
	if active:
		gear.stowed=true;gear._refresh()
	else:
		gear.select_weapon(0 if id=="talwar" else 4)
	spear.visible=active
func available() -> bool:
	return actor.get_node("CombatInput").available()
func _unhandled_input(event: InputEvent) -> void:
	if not available():return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_7 and actor.inventory.has_item("spear"):
			equip("spear");get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_B:
			throw_smoke();get_viewport().set_input_as_handled()
		elif event.physical_keycode in [KEY_H,KEY_G] and active:
			active=false;spear.hide();get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	cooldown=maxf(0,cooldown-delta)
	if active and not gear.stowed:active=false
	spear.visible=active
	if not active or not available():
		spear.hide();thrust=-1;return
	var rig: Skeleton3D=gear.skeleton
	var hand: Transform3D=rig.get_bone_global_pose(rig.find_bone("hand_r"))
	var camera: Camera3D=actor.get_node("CameraPivot/SpringArm3D/Camera3D")
	var direction: Vector3=-camera.global_basis.z;direction.y=0;direction=direction.normalized()
	var axis:=Vector3.UP
	if thrust>=0:
		thrust+=delta
		var raise: float=smoothstep(0,.12,thrust)*(1.0-smoothstep(.35,.5,thrust))
		axis=Vector3.UP.slerp(direction,raise).normalized()
		var extension: float=sin(minf(thrust/.5,1)*PI)*.35
		# Bring the shaft toward the player's aim line as it levels. Leaving
		# the palm at its carry-side offset made centred human targets miss.
		var carry_palm: Vector3=rig.to_global(hand*gear.palm_offsets["r"])
		var across_aim: Vector3=camera.global_basis.x
		var centre: Vector3=across_aim*clampf((actor.global_position-carry_palm).dot(across_aim),-.32,.32)*raise
		gear._solve_arm("r",hand.origin+rig.global_basis.inverse()*(direction*extension+Vector3.UP*.15+centre))
		if thrust>=.5:thrust=-1;axis=Vector3.UP
	hand=rig.get_bone_global_pose(rig.find_bone("hand_r"))
	var grip_contact: Vector3=hand*gear.palm_offsets["r"]
	# Align the shaft across the curled palm, rather than twisting the prop
	# independently of the wrist as it changes from carry to thrust.
	var local_axis: Vector3=rig.global_basis.inverse()*axis
	var across: Vector3=rig.global_basis.inverse()*camera.global_basis.x
	across=(across-local_axis*across.dot(local_axis)).normalized()
	if across.is_zero_approx():across=Vector3.RIGHT
	var grip_basis:=Basis(local_axis,across,local_axis.cross(across))
	var hand_basis: Basis=grip_basis*(gear.palm_axes["r"] as Basis).inverse()
	var hand_index: int=rig.find_bone("hand_r")
	var parent_index: int=rig.get_bone_parent(hand_index)
	gear._solve_arm("r",grip_contact-hand_basis*gear.palm_offsets["r"])
	rig.set_bone_pose_rotation(hand_index,(rig.get_bone_global_pose(parent_index).basis.inverse()*hand_basis).orthonormalized().get_rotation_quaternion())
	rig.force_update_all_bone_transforms()
	hand=rig.get_bone_global_pose(hand_index)
	var palm: Vector3=rig.to_global(hand*gear.palm_offsets["r"])
	spear.global_transform=Transform3D(Basis(Quaternion(Vector3.UP,axis)),palm-axis*.8)
	gear._grasp("r",.85)
	if thrust>=.15 and not landed:
		landed=true
		var query:=PhysicsRayQueryParameters3D.create(palm,palm+axis*1.11)
		query.exclude=[actor.get_rid()]
		var hit:=actor.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():preload("res://combat/damage_policy.gd").apply(hit.collider,28,actor,"spear")
func strike() -> bool:
	if not active or cooldown>0 or not available():return false
	cooldown=.75;thrust=0;landed=false
	WorldAudio.play_at("blade_swoosh",actor.global_position,-18)
	return true
func throw_smoke() -> bool:
	if cooldown>0 or not available() or not actor.inventory.has_item("smoke_bomb"):return false
	actor.inventory.remove_item("smoke_bomb",1);cooldown=1
	var camera: Camera3D=actor.get_node("CameraPivot/SpringArm3D/Camera3D")
	var origin:=actor.global_position+Vector3.UP
	var destination:=origin-camera.global_basis.z*4
	var query:=PhysicsRayQueryParameters3D.create(origin,destination,1);query.exclude=[actor.get_rid()]
	var hit:=actor.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():destination=hit.position+hit.normal*.3
	var cloud:=preload("res://combat/escape_smoke.gd").new();actor.get_parent().add_child(cloud);cloud.global_position=destination
	actor.inventory.message_requested.emit("Smoke cover · move away before it clears")
	return true
