extends Node3D
## Unnamed sepoy candidate reusing Dev's complete MPFB body and uniform source.
var route: Array[Vector3] = []
var route_index := 0
var duty := "rest"
var blocked := false
var body_collider: AnimatableBody3D
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var travel_speed := 0.0

func _ready() -> void:
	set_meta("combat_faction","british")
	animation_player = find_child("AnimationPlayer",true,false)
	assert(animation_player != null and animation_player.has_animation("Dev_walk_study"))
	animation_player.play("Dev_idle_study")
	body_collider = AnimatableBody3D.new()
	body_collider.name = "BodyCollider"
	body_collider.sync_to_physics = false
	add_child(body_collider)
	var collision := CollisionShape3D.new()
	collision.name = "BodyShape"
	var capsule := CapsuleShape3D.new()
	capsule.radius = .29
	capsule.height = 1.6
	collision.shape = capsule
	collision.position.y = .8
	body_collider.add_child(collision)

func assign_duty(label: String,points: Array[Vector3]) -> void:
	duty = label
	set_meta("duty",label)
	route = points.duplicate()
	route_index = 0

func _process(delta: float) -> void:
	if animation_player == null or get_meta("dead",false) or get_meta("knocked_out",false): return
	travel_speed = 0
	blocked = false
	if route_index < route.size():
		var toward := route[route_index]-global_position
		toward.y = 0
		if toward.length() < .15:
			route_index += 1
		else:
			var step := toward.normalized()*minf(toward.length(),1.15*delta)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = body_collider.get_node("BodyShape").shape
			query.transform = body_collider.get_node("BodyShape").global_transform
			query.transform.origin += step
			query.collision_mask = 1
			query.exclude = [body_collider.get_rid()]
			blocked = not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
			var ground_query := PhysicsRayQueryParameters3D.create(global_position+step+Vector3.UP*.6,global_position+step-Vector3.UP*.6)
			ground_query.exclude = [body_collider.get_rid()]
			var ground := get_world_3d().direct_space_state.intersect_ray(ground_query)
			blocked = blocked or ground.is_empty() or (not ground.is_empty() and ground.normal.y < .7)
			if not blocked:
				global_position += step
				global_position.y = ground.position.y
				travel_speed = step.length()/maxf(delta,.001)
				rotation.y = rotate_toward(rotation.y,atan2(toward.x,toward.z),delta*3)
				body_collider.force_update_transform()
	var clip := "Dev_walk_study" if travel_speed > .01 else "Dev_idle_study"
	if animation_player.current_animation != clip: animation_player.play(clip,.2)
	animation_player.speed_scale = 1.0
	set_meta("duty_blocked",blocked)
