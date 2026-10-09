extends Node
## Paired rear restraint; range/heading/obstacle checks precede any control lock.
var actor: CharacterBody3D
var visual: Node3D
var victim: Node3D
var age := 0.0
var active := false
var contact_error := 0.0
var victim_movement := false
var neck_bone := -1
var palms: Dictionary = {}
func _ready() -> void:
	actor=get_parent()
	visual=actor.get_node("VisualRoot/CharacterVisual")
	for side in ["l", "r"]:
		var hand: int=visual.bones["hand_"+side]
		palms[side]=[hand, visual.skeleton.get_bone_parent(hand)]
	process_priority=40
	set_process(false)
	set_physics_process(false)
	if not InputMap.has_action("rear_grapple"):
		InputMap.add_action("rear_grapple")
		var key:=InputEventKey.new();key.physical_keycode=KEY_B
		InputMap.action_add_event("rear_grapple",key)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("rear_grapple"):return
	if active: cancel()
	elif actor.get_node("CombatInput").available(): begin()
	get_viewport().set_input_as_handled()

func begin() -> bool:
	if not actor.get_node("CombatInput").available():return false
	var closest:=1.05
	var chosen: Node3D
	for target in get_tree().get_nodes_in_group("combat_actors"):
		if target.get_meta("combat_faction","indian") not in ["british","police","training"] or target.get_meta("dead",false) or target.get_meta("knocked_out",false):continue
		if target.get_meta("training_partner",false):
			var lesson: Node=get_tree().root.find_child("DevStory",true,false)
			if lesson==null or not lesson.practice_allowed(target,"takedown"):continue
		var offset: Vector3=actor.global_position-target.global_position
		offset.y=0
		var distance:=offset.length()
		if distance < .48 or distance>=closest or offset.normalized().dot(target.global_basis.z)>-.6:continue
		if target.travel_speed>.2:continue
		var sight:=PhysicsRayQueryParameters3D.create(actor.global_position,target.global_position+Vector3.UP*.9,1)
		sight.exclude=[actor.get_rid(),target.body_collider.get_rid()]
		if not actor.get_world_3d().direct_space_state.intersect_ray(sight).is_empty():continue
		chosen=target;closest=distance
	if chosen==null:return false
	victim=chosen;age=0;active=true
	set_process(true)
	set_physics_process(true)
	neck_bone=victim._skeleton.find_bone("neck_01")
	victim_movement=victim.movement_enabled
	victim.set_meta("grappled",true)
	victim.movement_enabled=false
	victim.combat_react("held")
	visual.equipment.stowed=true
	visual.equipment._refresh()
	actor.set_meta("paired_combat",true)
	actor.velocity=Vector3.ZERO
	if not victim.get_meta("training_partner",false):
		actor.get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED,"police_crime_observers","report_assault",victim)
	return true

func _process(delta: float) -> void:
	if not active:return
	if not is_instance_valid(victim) or victim.get_meta("dead",false) or actor.health<=0 or actor.get_meta("detention_action","")!="":cancel();return
	age+=delta
	var offset:=victim.global_position-actor.global_position
	offset.y=0
	if offset.length()>1.2:cancel();return
	actor.get_node("VisualRoot").global_rotation.y=atan2(offset.x,offset.z)
	visual.motion_tree.set_melee(4,minf(age/1.2,1.0))
	visual.motion_tree.advance(0)
	var rig: Skeleton3D=victim._skeleton
	var chest:=rig.to_global(rig.get_bone_global_pose(neck_bone).origin)
	contact_error=0
	var hero_rig: Skeleton3D=visual.skeleton
	var equipment: Node3D=visual.equipment
	var weight:=smoothstep(0,.3,age)*(1.0-smoothstep(1.0,1.2,age))
	for side in ["l","r"]:
		var sign_side:=1.0 if side=="l" else -1.0
		var target:=chest+victim.global_basis*Vector3(.09*sign_side,.005,-.035)
		var inward: Vector3=victim.global_basis*Vector3(-sign_side,0,0)
		var forward: Vector3=victim.global_basis.z.normalized()
		var across:=forward.cross(inward).normalized()
		var palm_basis:=Basis(across,forward,inward)
		var desired: Basis=hero_rig.global_basis.inverse()*palm_basis*(equipment.palm_axes[side] as Basis).inverse()
		var hand_index: int=palms[side][0]
		var parent: int=palms[side][1]
		var hand:=hero_rig.get_bone_global_pose(hand_index)
		var pose_basis:=Basis(hand.basis.get_rotation_quaternion().slerp(desired.get_rotation_quaternion(),weight))
		var local_target: Vector3=(hand*equipment.palm_offsets[side]).lerp(hero_rig.to_local(target),weight)
		# Solve the wrist from the palm offset, then orient it toward the collar.
		for iteration in 2:
			equipment._solve_arm(side,local_target-pose_basis*equipment.palm_offsets[side])
			hero_rig.set_bone_pose_rotation(hand_index,(hero_rig.get_bone_global_pose(parent).basis.inverse()*pose_basis).orthonormalized().get_rotation_quaternion())
			hero_rig.force_update_all_bone_transforms()
		equipment._grasp(side,.42*weight)
		var palm: Vector3=hero_rig.to_global(hero_rig.get_bone_global_pose(hand_index)*equipment.palm_offsets[side])
		contact_error=maxf(contact_error,palm.distance_to(target))
	if age>=1.2:
		victim.get_node("Vitality").receive_hit(100,actor,"takedown")
		cancel()

func cancel() -> void:
	if is_instance_valid(victim):
		victim.set_meta("grappled",false)
		if not victim.get_meta("knocked_out",false) and not victim.get_meta("dead",false):
			victim.get_node("CombatMotion").state=""
			victim.set_meta("combat_action","");victim.animation_tree.set("parameters/combat/blend_amount",0.0)
			victim.movement_enabled=victim_movement
	active=false;victim=null
	set_process(false)
	set_physics_process(false)
	actor.set_meta("paired_combat",false)
	for solver in visual.climb_ik.values():solver.influence=0;solver.stop()
	visual.motion_tree.set_melee(0,-1)

func _physics_process(_delta: float) -> void:
	if not active or not is_instance_valid(victim):return
	var desired:=victim.global_position-victim.global_basis.z*.62
	desired.y=actor.global_position.y
	var offset:=desired-actor.global_position
	if offset.length()>.01:
		actor.velocity=offset.normalized()*minf(.6,offset.length()*8)
		actor.move_and_slide()
