extends Node
## Interruptible civilian reaction; navigation and collision remain physical.
const Route = preload("res://world/suryagarh/settlements/resident_walk_route.gd")
var actor: Node3D
var viewer: Node3D
var state := ""
var age := 0.0
var safe_age := 0.0
var source: Node3D
var origin := Vector3.ZERO
var origin_yaw := 0.0
var destination := Vector3.INF
var path: Array[Vector3] = []
var navigation_pending := false
var attack_age := 0.0
var attack_delivered := false
var attack_started := false
var cooldown := 0.0
var prior_processing := false
var last_hit_kind := ""
var threat_ttl := 0.0
var sheltered := false
var upright_shape := Transform3D.IDENTITY

func _ready() -> void:
	actor=get_parent();process_priority=20
	upright_shape=actor.body_collider.get_node("BodyShape").transform
	add_to_group("civilian_reactions");add_to_group("independent_npc_activities")
	set_physics_process(false)
	preload("res://world/suryagarh/settlements/activity_save.gd").apply_late(self)

func eligible() -> bool:
	return not actor.get_meta("dead",false) and not actor.get_meta("knocked_out",false) and not actor.get_meta("grappled",false) and not actor.get_meta("mission_active",false) and not actor.get_meta("external_combat_motion",false) and not actor.get_meta("police_engaged",false)

func witness(threat: Node3D, armed: bool, directly_hit := false) -> void:
	if not eligible() or not is_instance_valid(threat) or threat==actor:return
	if state=="" and cooldown>0 and not directly_hit:return
	threat_ttl=3.0
	if state!="" and source==threat:
		if armed and state=="guard":state="startle";age=0
		return
	if state=="":
		origin=actor.global_position;origin_yaw=actor.global_rotation.y;prior_processing=actor.is_processing()
		actor.set_meta("civilian_reacting",true)
	source=threat;safe_age=0.0
	# Retaliation is defensive and only for a direct unarmed assault. Witnesses
	# and workers do not become indiscriminate attackers.
	var brave: bool=actor.get_meta("world_role","") in ["cart_maker","labourer"] or posmod(str(actor.name).hash(),4)==0 or (actor.movement_profile==&"female" and posmod(str(actor.name).hash(),2)==0)
	state="guard" if directly_hit and not armed and brave else "startle"
	age=0.0;attack_age=0.0;attack_started=false;attack_delivered=false;path.clear();navigation_pending=false;destination=Vector3.INF
	set_physics_process(true)

func impact(relative_speed: float, other: Node3D) -> void:
	if not eligible() or state!="" or cooldown>0 or relative_speed<2.2:return
	if state=="":origin=actor.global_position;origin_yaw=actor.global_rotation.y;prior_processing=actor.is_processing()
	actor.set_meta("civilian_reacting",true)
	source=other;age=0;safe_age=0
	state="fall" if relative_speed>=5.5 else "stumble"
	actor.combat_react("fall" if state=="fall" else "hit")
	set_physics_process(true)

func receive_navigation(route: Array[Vector3], goal: Vector3) -> void:
	if goal!=destination or state not in ["flee","return"]:return
	navigation_pending=false;path=route
	if not path.is_empty() and actor.global_position.distance_to(path[0])<.1:path.pop_front()

func _physics_process(delta: float) -> void:
	cooldown=maxf(0,cooldown-delta)
	if not eligible():finish();return
	if state=="":
		if cooldown<=0:set_physics_process(false)
		return
	age+=delta
	threat_ttl=maxf(0,threat_ttl-delta)
	actor.set_meta("fear",.8 if state!="return" else .25)
	if state in ["fall","stumble"]:
		if state=="fall":fall_collision(smoothstep(0,1,minf(age,1.0)))
		if state=="fall" and age>3.0 and actor.get_node("CombatMotion").state=="down" and can_rise():actor.combat_react("rise");state="rise";age=0
		elif state=="stumble" and age>1.2:finish()
		return
	if state=="rise":
		fall_collision(1.0-smoothstep(0,1,minf(age,1.0)))
		if age>1.1:finish()
		return
	if is_instance_valid(source) and state not in ["return"] and threat_ttl>0:
		var distance:=actor.global_position.distance_to(source.global_position)
		if distance>18:safe_age+=delta
		else:safe_age=0
	else:safe_age+=delta
	if state=="startle":
		pose("cower",delta)
		if age>.75:state="flee";age=0;choose_escape()
	elif state=="guard":
		if is_instance_valid(source):
			var facing:=source.global_position-actor.global_position
			actor.global_rotation.y=rotate_toward(actor.global_rotation.y,atan2(facing.x,facing.z),delta*3.0)
			actor.body_collider.force_update_transform()
			facing.y=0.0
			if not attack_started and facing.length()>.65 and facing.length()<2.0:
				path.assign([actor.global_position+facing.normalized()*(facing.length()-.65)])
				move_step(delta,.65)
		if not attack_started:pose("guard",delta)
		else:actor.travel_speed=0.0
		if not is_instance_valid(source) or actor.global_position.distance_to(source.global_position)>2.0:
			state="flee";age=0;choose_escape();return
		attack_age+=delta
		if not attack_started and attack_age>=1.0 and actor.get_meta("combat_action","")!="hit":
			attack_age=0;attack_delivered=false;attack_started=true
			var style:String=actor.get_meta("civilian_defence_style","slap" if actor.movement_profile==&"female" else "strike")
			actor.combat_react("slap" if style=="slap" else "strike")
		if attack_started and attack_age>=.28 and attack_age<=.52 and not attack_delivered:
			var world:=preload("res://systems/world_context.gd").find_world(actor)
			var combat:=world.get_node_or_null("CombatEncounters") if world!=null else null
			if combat!=null and combat.strike_hits_actor(actor,source):
				var receiver: Node=source.get_node_or_null("Vitality")
				attack_delivered=preload("res://combat/damage_policy.gd").apply(receiver if receiver!=null else source,5.0,actor,"punch")
		if attack_started and attack_age>=.65:attack_started=false;attack_age=0
		if age>4.0:state="flee";age=0;choose_escape()
	elif state in ["flee","return"]:
		if not path.is_empty():move_step(delta,2.8 if state=="flee" else .85)
		else:
			pose("cower" if state=="flee" else "listen",delta)
			if not navigation_pending and state=="flee":state="hide";age=0
			elif not navigation_pending and state=="return":
				if actor.global_position.distance_to(origin)<.15:state="align";age=0
				else:state="hide";age=0
	elif state=="align":
		pose("listen",delta)
		actor.global_rotation.y=rotate_toward(actor.global_rotation.y,origin_yaw,delta*3.0)
		actor.body_collider.force_update_transform()
		if absf(angle_difference(actor.global_rotation.y,origin_yaw))<.02:finish()
	elif state=="hide":
		pose("cower",delta)
		if age>8.0 and safe_age>3.0:
			state="return";age=0;destination=origin
			navigation_pending=preload("res://systems/navigation_work_queue.gd").request(self,actor,destination)
	actor.set_meta("civilian_reaction",state)

func choose_escape() -> void:
	path.clear()
	var away:=actor.global_position-source.global_position if is_instance_valid(source) else actor.global_basis.z
	away.y=0
	if away.length()<.01:away=Vector3.RIGHT
	destination=actor.global_position+away.normalized()*9.0
	sheltered=false
	# A building only qualifies as cover when its solid wall actually occludes
	# the threat. Navigation still has to reach the far side physically.
	var world:=preload("res://systems/world_context.gd").find_world(actor)
	var best:=INF
	if world!=null and is_instance_valid(source):
		for home: Node3D in get_tree().get_nodes_in_group("bhairavpur_home"):
			if not world.is_ancestor_of(home) or home.global_position.distance_squared_to(actor.global_position)>625:continue
			var offset:=home.global_position-source.global_position;offset.y=0
			if offset.length()<.1:continue
			var candidate:=home.global_position+offset.normalized()*7.0
			var height:=Route.support(actor,candidate)
			if not is_finite(height):continue
			candidate.y=height
			var ray:=PhysicsRayQueryParameters3D.create(source.global_position+Vector3.UP*1.2,candidate+Vector3.UP*1.1,1)
			var hit:=actor.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty():continue
			if home.is_ancestor_of(hit.collider) and candidate.distance_squared_to(actor.global_position)<best:
				best=candidate.distance_squared_to(actor.global_position);destination=candidate;sheltered=true
	# Roadside walls can provide shelter even when they are outside the home registry.
	if not sheltered and is_instance_valid(source):
		for turn in [0.0, -.6, .6, -1.2, 1.2, -1.8, 1.8]:
			var candidate:=actor.global_position+away.normalized().rotated(Vector3.UP,turn)*8.0
			var height:=Route.support(actor,candidate)
			if not is_finite(height):continue
			candidate.y=height
			var query:=PhysicsRayQueryParameters3D.create(source.global_position+Vector3.UP*1.2,candidate+Vector3.UP*1.2,1)
			query.exclude=[actor.body_collider.get_rid()]
			var wall:=actor.get_world_3d().direct_space_state.intersect_ray(query)
			if wall.is_empty() or absf(Vector3(wall.normal).y)>.3:continue
			query.from=source.global_position+Vector3.UP*.65;query.to=candidate+Vector3.UP*.65
			var low:=actor.get_world_3d().direct_space_state.intersect_ray(query)
			if low.is_empty() or low.collider!=wall.collider:continue
			destination=candidate;sheltered=true;break
	var support:=Route.support(actor,destination)
	if not is_finite(support):state="hide";age=0;return
	destination.y=support
	navigation_pending=preload("res://systems/navigation_work_queue.gd").request(self,actor,destination)
	if not navigation_pending:state="hide";age=0

func pose(label: String, delta: float) -> void:
	if actor.has_method("perform"):actor.perform(label,delta,false,.8);return
	actor.travel_speed=0;actor._set_animation(&"idle",delta)
	var weight:=smoothstep(0,.35,age)
	for bone in ["head","spine_02","upperarm_l","upperarm_r","lowerarm_l","lowerarm_r"]:
		if not actor._bones.has(bone):continue
		var pitch: float=-.12 if bone=="head" else .10 if bone=="spine_02" else -1.0 if bone.begins_with("upperarm") else -1.4
		var index: int=actor._bones[bone]
		actor._skeleton.set_bone_pose_rotation(index,actor._skeleton.get_bone_pose_rotation(index)*Quaternion(actor._pitch_axes[bone],pitch*weight))

func move_step(delta: float, speed: float) -> void:
	var target: Vector3=path[0]
	var offset:=target-actor.global_position;var motion:=offset.limit_length(speed*delta)
	var shape: CollisionShape3D=actor.body_collider.get_node("BodyShape")
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=shape.global_transform;query.transform.origin.y+=.08
	query.motion=motion;query.collision_mask=1;query.exclude=[actor.body_collider.get_rid()];query.margin=.01
	var clear:=actor.get_world_3d().direct_space_state.cast_motion(query)[0]>=.99
	query.transform.origin+=motion;query.motion=Vector3.ZERO
	if not clear or not actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():path.clear();return
	actor.global_position+=motion
	actor.global_rotation.y=rotate_toward(actor.global_rotation.y,atan2(offset.x,offset.z),delta*3.0)
	if actor.has_method("perform"):
		actor.animation_tree.set("parameters/work_pose/blend_amount",0.0)
		actor.activity="flee" if state=="flee" else "return"
	actor.walk_direction=1.0
	actor.travel_speed=speed;actor._set_animation(&"walk",delta)
	if state=="flee" and actor.get("run_enabled")!=true:
		var phase: float=actor._walk_phase*TAU
		for bone in ["spine_02","upperarm_l","upperarm_r","lowerarm_l","lowerarm_r"]:
			var index: int=actor._bones.get(bone,-1)
			if index<0:continue
			var angle: float=.10 if bone=="spine_02" else -.65 if bone.begins_with("lowerarm") else .25*sin(phase+(PI if bone.ends_with("r") else 0.0))
			actor._skeleton.set_bone_pose_rotation(index,actor._skeleton.get_bone_pose_rotation(index)*Quaternion(actor._pitch_axes[bone],angle))
	actor.body_collider.force_update_transform()
	if actor.global_position.distance_to(target)<.04:path.pop_front()

func finish() -> void:
	state="";age=0;cooldown=3.0;path.clear();navigation_pending=false
	actor.set_meta("civilian_reacting",false);actor.set_meta("civilian_reaction","");actor.set_meta("fear",0.0)
	actor.foot_plant.clear();actor.travel_speed=0
	actor.body_collider.get_node("BodyShape").transform=upright_shape
	# Keep clocks/identity owned by the interrupted job; it resumes next tick.
	set_physics_process(true)

func fall_collision(amount: float) -> void:
	var shape: CollisionShape3D=actor.body_collider.get_node("BodyShape")
	shape.position=upright_shape.origin.lerp(Vector3(0,.25,0),amount)
	shape.basis=upright_shape.basis*Basis(Vector3.RIGHT,PI*.5*amount)
	actor.body_collider.force_update_transform()

func can_rise() -> bool:
	var shape: CollisionShape3D=actor.body_collider.get_node("BodyShape")
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape
	query.transform=actor.body_collider.global_transform*upright_shape
	query.transform.origin.y+=.03
	query.exclude=[actor.body_collider.get_rid()];query.collision_mask=1;query.margin=.005
	return actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func export_state() -> Dictionary:
	return {"state":state,"age":age,"safe_age":safe_age,"origin_yaw":origin_yaw,"origin":[origin.x,origin.y,origin.z],"position":[actor.global_position.x,actor.global_position.y,actor.global_position.z]}
func restore_state(data: Dictionary) -> void:
	if data.is_empty() or data.get("state","")=="" or not eligible():return
	var at: Array=data.get("position",[]);var home: Array=data.get("origin",[])
	if at.size()!=3 or home.size()!=3:return
	actor.global_position=Vector3(float(at[0]),float(at[1]),float(at[2]));origin=Vector3(float(home[0]),float(home[1]),float(home[2]))
	origin_yaw=float(data.get("origin_yaw",actor.global_rotation.y))
	state="hide";age=0;safe_age=4;actor.set_meta("civilian_reacting",true);set_physics_process(true)
