extends Node
## Local self-defence only; police/story/grapple owners keep arbitration priority.
var actor: Node3D
var opponent: CharacterBody3D
var age := 0.0
var cooldown := .8
var active := false
var guarding := false
var provoked := false
var previous_movement := false
var face: RefCounted
var face_owner: Node
var next_sense := 0.0
var counter_age := -1.0
var counter_landed := false
var face_build_usec := 0
var origin := Vector3.ZERO
var returning := false
var return_path: Array[Vector3]=[]
var return_pending := false
var return_retry := 0.0
var evade_left := 0.0
var evade_direction := Vector3.ZERO
var previous_walk_direction := 1.0

func _ready() -> void:
	actor=get_parent();process_priority=20;process_physics_priority=50
	var world:=preload("res://systems/world_context.gd").find_world(actor)
	if world!=null:face_owner=world.get_node_or_null("CivilianAwareness")
	set_process(false);set_physics_process(false)

func alert(attacker: Node, attacked := true) -> void:
	if not attacker is CharacterBody3D or attacker.name!="Player" or actor.get_meta("combat_faction","") not in ["british","police"]:return
	if not active:
		previous_movement=actor.movement_enabled;cooldown=.8;origin=actor.global_position
		previous_walk_direction=actor.walk_direction
		actor.set_meta("defence_previous_movement",previous_movement)
	returning=false
	provoked=provoked or attacked
	opponent=attacker;active=true;age=0;set_process(true);set_physics_process(true)
	if face==null and not is_instance_valid(face_owner):
		var world:=preload("res://systems/world_context.gd").find_world(actor)
		if world!=null:face_owner=world.get_node_or_null("CivilianAwareness")
	if face==null and is_instance_valid(face_owner):
		var started:=Time.get_ticks_usec()
		face=face_owner.configure_face(actor)
		if face.entries.is_empty():
			for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
				if mesh.find_blend_shape_by_name("dialogue_anger")==2:face.entries.append({"node":mesh,"source":mesh.mesh})
		face_build_usec=Time.get_ticks_usec()-started

func owned_elsewhere() -> bool:
	return actor.get_meta("police_engaged",false) or actor.get_meta("external_combat_motion",false) or actor.get_meta("story_guard",false) or actor.get_meta("mission_active",false) or actor.get_meta("city_custody",false) or actor.get_meta("grappled",false) or actor.get_meta("civilian_reacting",false)

func blocks(attacker: Node, kind: String) -> bool:
	if not active or not guarding or attacker!=opponent or kind not in ["punch","kick"]:return false
	var direction: Vector3=opponent.global_position-actor.global_position;direction.y=0
	return direction.length()<1.7 and actor.global_basis.z.dot(direction.normalized())>.5

func _physics_process(delta: float) -> void:
	if not active:return
	if returning:
		return_to_duty(delta);return
	if not is_instance_valid(opponent) or actor.get_meta("dead",false) or actor.get_meta("knocked_out",false) or opponent.health<=0:
		finish();return
	age+=delta;cooldown=maxf(0,cooldown-delta)
	var offset:=opponent.global_position-actor.global_position;offset.y=0
	if (age>12.0 and not actor.get_meta("police_engaged",false)) or offset.length()>12:
		finish();return
	if opponent.get_meta("story_cinematic",false) or owned_elsewhere():
		if actor.get_meta("defending",false):
			actor.walk_direction=previous_walk_direction;actor.set_meta("defending",false)
		guarding=false;return
	actor.movement_enabled=false;actor.travel_speed=0;actor.set_meta("defending",true)
	# Contact identifies the attacker, but ongoing sight still respects walls.
	var visible: bool=preload("res://systems/visual_perception.gd").sees(actor,opponent,12.0)
	if offset.length_squared()>.001:
		var desired:=atan2(offset.x,offset.z)
		var turn:=absf(angle_difference(actor.global_rotation.y,desired))
		actor.set_meta("patrol_turning",turn>.3)
		actor._turn_progress=clampf(1.0-turn/PI,0,1)
		actor.global_rotation.y=rotate_toward(actor.global_rotation.y,desired,delta*4.8)
	if actor.get_meta("combat_action","")=="hit":guarding=false;return
	var input: Node=opponent.get_node_or_null("CombatInput")
	var visual: Node=opponent.get_node_or_null("VisualRoot/CharacterVisual")
	var blade: Node=opponent.get_node_or_null("TalwarSlash")
	var spear: Node=opponent.get_node_or_null("ChachaKit")
	var bow: Node=opponent.get_node_or_null("BowCombat")
	var incoming: bool=input!=null and (input.punch_time>=0 or input.kick_time>=0 or (blade!=null and blade.elapsed<blade.DURATION) or (spear!=null and spear.thrust>=0) or (bow!=null and bow.aiming) or (visual!=null and visual.equipment.aiming))
	var armed: bool=visual!=null and (not visual.equipment.stowed or (opponent.get_node_or_null("ChachaKit")!=null and opponent.get_node("ChachaKit").active))
	guarding=visible and offset.length()<2.2 and counter_age<0
	if guarding and incoming:actor.set_meta("defence_guard",true)
	else:actor.set_meta("defence_guard",false)
	if evade_left>0.0:
		var elapsed:=minf(delta,evade_left)
		actor.walk_direction=-1.0 if evade_direction.dot(actor.global_basis.z)<-.2 else 1.0
		step_away(evade_direction*(.3/.18)*elapsed)
		evade_left-=elapsed
		return
	actor.walk_direction=1.0
	if visible and incoming and armed and cooldown<=0 and offset.length()<10.0:
		var evade: Vector3=-offset.normalized() if offset.length()<2.0 else Vector3.UP.cross(offset.normalized())
		evade_direction=evade;evade_left=.18;cooldown=.8;return
	if provoked and visible and offset.length()>.85 and offset.length()<10 and counter_age<0:
		step_away(offset.normalized()*minf(delta*1.8,offset.length()-.85))
	if provoked and counter_age<0 and visible and offset.length()<1.05 and cooldown<=0:
		counter_age=0;counter_landed=false;guarding=false;actor.combat_react("strike")
	if counter_age>=0:
		counter_age+=delta
		if counter_age>.25 and counter_age<.55 and not counter_landed:
			var point: Vector3=actor._skeleton.to_global(actor._skeleton.get_bone_global_pose(actor._skeleton.find_bone("hand_r")).origin)
			var query:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new();sphere.radius=.14
			query.shape=sphere;query.transform.origin=point;query.collision_mask=1;query.exclude=[actor.body_collider.get_rid()]
			for hit in actor.get_world_3d().direct_space_state.intersect_shape(query,8):
				if hit.collider==opponent and visible:opponent.receive_combat_hit(8,actor);counter_landed=true;break
		if counter_age>=.7:counter_age=-1;cooldown=.8

func step_away(change: Vector3) -> void:
	if actor._patrol_body_blocked(change):return
	var excluded: Array[RID]=[actor.body_collider.get_rid()]
	if is_instance_valid(opponent):excluded.append(opponent.get_rid())
	var query:=PhysicsRayQueryParameters3D.create(actor.global_position+change+Vector3.UP*.25,actor.global_position+change-Vector3.UP*.3,1,excluded)
	var support:=actor.get_world_3d().direct_space_state.intersect_ray(query)
	if support.is_empty() or absf(support.position.y-actor.global_position.y)>.2:return
	actor.global_position=support.position;actor.travel_speed=1.8;actor.body_collider.force_update_transform()

func _process(delta: float) -> void:
	if is_instance_valid(opponent) and (opponent.get_meta("story_cinematic",false) or actor.get_meta("mission_active",false)):return
	if face!=null:
		var hurt: bool=actor.get_meta("combat_action","")=="hit"
		face.apply(.65 if hurt else .1,0,.7 if hurt else .9,.3 if hurt else .05,.15 if hurt else 0.0)
	if owned_elsewhere() or not guarding or actor.get_meta("combat_action","")!="":return
	preload("res://combat/guard_pose.gd").apply(actor,age)

func finish(force := false) -> void:
	if not force and previous_movement and not owned_elsewhere() and not actor.get_meta("dead",false) and not actor.get_meta("knocked_out",false) and actor.global_position.distance_to(origin)>.05:
		returning=true;guarding=false;counter_age=-1;actor.movement_enabled=false;actor.set_meta("defending",true);return
	if not owned_elsewhere():
		actor.movement_enabled=previous_movement;actor.travel_speed=0;actor.walk_direction=previous_walk_direction
	actor.set_meta("defending",false);actor.set_meta("defence_guard",false)
	if not owned_elsewhere():actor.set_meta("patrol_turning",false)
	if face!=null:face.apply(0,0,0,0,0)
	actor.remove_meta("defence_previous_movement")
	evade_left=0.0
	active=false;guarding=false;provoked=false;returning=false;return_path.clear();counter_age=-1;set_process(false);set_physics_process(false)

func receive_navigation(points: Array[Vector3], goal: Vector3) -> void:
	return_pending=false
	if returning and goal.distance_to(origin)<.1:return_path=points

func return_to_duty(delta: float) -> void:
	actor.walk_direction=1.0
	if owned_elsewhere() or actor.get_meta("dead",false) or actor.get_meta("knocked_out",false):finish(true);return
	if actor.global_position.distance_to(origin)<.05:finish(true);return
	return_retry=maxf(0,return_retry-delta)
	while not return_path.is_empty() and actor.global_position.distance_to(return_path[0])<.15:return_path.pop_front()
	var goal: Vector3=origin if return_path.is_empty() else return_path[0]
	var toward:=goal-actor.global_position;toward.y=0
	actor.global_rotation.y=rotate_toward(actor.global_rotation.y,atan2(toward.x,toward.z),delta*4.8)
	var before:=actor.global_position
	step_away(toward.normalized()*minf(delta*1.5,toward.length()))
	if before.distance_to(actor.global_position)<.002 and not return_pending and return_retry<=0:
		return_pending=preload("res://systems/navigation_work_queue.gd").request(self,actor,origin)
		return_retry=2.0
