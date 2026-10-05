extends Node
## Terrain-following resident travel with swept collision and independent cadence.
var actor: Node3D
var route: Array[Vector2]=[]
var goal := 1
var direction := 1
var wait := 0.0
var speed := .85
var distance_walked := 0.0
var visits := 0
var blocked_frames := 0
var last_obstacle := ""
var layout := preload("res://world/suryagarh/landscape_layout.gd").new()
var paused := false
var initial_wait := 0.0
var clock: Node
var closing := false
var ankle_offsets:Dictionary={}
var turn_angle:=0.0

func _ready() -> void:
	clock = get_tree().root.find_child("GameTimeSystem",true,false)

func configure(person: Node3D, points: Array[Vector2], offset: float) -> void:
	actor=person;route=points;initial_wait=offset;wait=offset
	actor.set_process(false)
	for side in ["l","r"]:ankle_offsets[side]=actor.foot_plant.ankle_height[side]-actor.global_position.y

func _physics_process(delta: float) -> void: tick(delta)

func tick(delta: float) -> void:
	if paused or actor.get_meta("dead",false):return
	if clock != null:
		var open: bool = clock.current_hour >= 6 and clock.current_hour < 18
		if not open:
			if direction > 0 and not closing:
				direction=-1;goal=maxi(0,goal-1);wait=0
			closing=true
			if goal==0 and actor.global_position.distance_to(Vector3(route[0].x,layout.height(route[0].x,route[0].y),route[0].y))<.05:
				actor.set("travel_speed",0.0);actor.call("_set_animation",&"idle",delta);actor.set_meta("street_action","home_at_night");return
		else: closing=false
	if wait>0:
		wait=maxf(0,wait-delta)
		actor.set("travel_speed",0.0);actor.call("_set_animation",&"idle",delta)
		return
	var next: Vector2=route[goal]
	var target:=Vector3(next.x,layout.height(next.x,next.y),next.y)
	var offset:=target-actor.global_position
	var desired:=atan2(offset.x,offset.z)
	var remaining:=absf(angle_difference(actor.global_rotation.y,desired))
	if remaining>.08 and offset.length()>.04:
		if turn_angle<=0:turn_angle=remaining
		actor.global_rotation.y=rotate_toward(actor.global_rotation.y,desired,delta*2.8)
		actor._turn_progress=clampf(1-remaining/turn_angle,0,1)
		actor.travel_speed=0;actor._set_animation(&"turn",delta)
		actor.foot_plant.clear();actor.get_node("BodyCollider").force_update_transform()
		return
	turn_angle=0
	var amount:=minf(offset.length(),speed*delta)
	var motion:=offset.normalized()*amount
	var shape:CollisionShape3D=actor.get_node("BodyCollider/BodyShape")
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape.shape;query.transform=shape.global_transform
	query.transform.origin+=Vector3.UP*.025
	query.motion=motion;query.margin=.008;query.collision_mask=1
	query.exclude=[actor.get_node("BodyCollider").get_rid()]
	var safe:=actor.get_world_3d().direct_space_state.cast_motion(query)
	if safe[0]<.99:
		blocked_frames+=1
		actor.set("travel_speed",0.0);actor.call("_set_animation",&"idle",delta)
		actor.set_meta("street_action","waiting_for_clear_path")
		return
	actor.global_position+=motion
	actor.global_rotation.y=rotate_toward(actor.global_rotation.y,desired,delta*2.8)
	actor.set("travel_speed",amount/maxf(delta,.001))
	for side in ["l","r"]:actor.foot_plant.ankle_height[side]=actor.global_position.y+ankle_offsets[side]
	actor.call("_set_animation",&"walk",delta)
	actor.get_node("BodyCollider").force_update_transform()
	distance_walked+=amount
	actor.set_meta("street_action","walking_to_market" if direction>0 else "walking_home")
	if actor.global_position.distance_to(target)<.035:
		if goal==route.size()-1 or goal==0:
			visits+=1
			if goal==0 and closing:
				wait=0;return
			direction=-direction;wait=6.0
			actor.set_meta("street_action","market_visit" if goal>0 else "home_pause")
		goal+=direction
