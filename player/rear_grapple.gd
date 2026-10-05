extends Node
## Paired rear restraint; range/heading/obstacle checks precede any control lock.
var actor: CharacterBody3D
var visual: Node3D
var victim: Node3D
var age := 0.0
var active := false
var contact_error := 0.0
var victim_movement := false
func _ready() -> void:
	actor=get_parent()
	visual=actor.get_node("VisualRoot/CharacterVisual")
	process_priority=40
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
		if target.get_meta("combat_faction","indian") not in ["british","police"] or target.get_meta("dead",false) or target.get_meta("knocked_out",false):continue
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
	victim_movement=victim.movement_enabled
	victim.set_meta("grappled",true)
	victim.movement_enabled=false
	victim.combat_react("held")
	visual.equipment.stowed=true
	visual.equipment._refresh()
	actor.set_meta("paired_combat",true)
	actor.velocity=Vector3.ZERO
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
	var chest:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("neck_01")).origin)
	contact_error=0
	for side in ["l","r"]:
		var target:=chest+victim.global_basis*Vector3(.10 if side=="l" else -.10,.015,-.06)
		visual.climb_targets[side].global_position=target
		var solver: SkeletonIK3D=visual.climb_ik[side]
		solver.influence=smoothstep(0,.3,age)
		solver.start(true)
		var hand: Vector3=visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.bones["hand_"+side]).origin)
		contact_error=maxf(contact_error,hand.distance_to(target))
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
