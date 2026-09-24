extends CharacterBody3D
## Mountable vehicle contract: seat_world(), can_board(), board(), dismount().
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const BOAT = preload("res://assets/vehicles/boats/river_boat/vehicle_river_boat_01.glb")
var layout := Layout.new()
var rider: CharacterBody3D
var speed: float = 0.0
var row_phase: float = 0.0
var hull: Node3D
var paddle: Node3D
var paddle_stow: Transform3D
var paddle_blend := 0.0
var row_effort := 0.0
var saved_layer: int
var saved_mask: int
var mooring := Vector3.ZERO

func _ready() -> void:
	add_to_group("mountable_vehicles")
	collision_layer = 1
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	hull = BOAT.instantiate()
	hull.rotation.y = PI/2
	add_child(hull)
	_add_dry_floor()
	paddle = hull.find_child("boat_paddle",true,false)
	if paddle != null: paddle_stow = paddle.transform
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.26,0.62,4.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.05
	add_child(collision)
	var z: float = 235.0
	position = Vector3(layout.river_x(z)-layout.river_width(z)+4,0.03,z)
	mooring = position

func _add_dry_floor() -> void:
	# The source hull floor sits below the river plane; a shallow inner deck keeps the
	# visible boat interior dry while leaving the outer hull's draft in the water.
	var source: MeshInstance3D = hull.find_child("river_boat_floor",true,false)
	var wood: Material = source.mesh.surface_get_material(0) if source != null else null
	var sections := [Vector2(-2.03,.04),Vector2(-1.91,.18),Vector2(-1.53,.34),Vector2(-1.25,.40),Vector2(-.75,.51),Vector2(0,.54),Vector2(.75,.51),Vector2(1.25,.40),Vector2(1.53,.34),Vector2(1.91,.18),Vector2(2.03,.04)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	if wood != null: surface.set_material(wood)
	for i in range(sections.size()-1):
		var a: Vector2 = sections[i]
		var b: Vector2 = sections[i+1]
		for point in [Vector2(a.x,-a.y),Vector2(b.x,b.y),Vector2(b.x,-b.y),Vector2(a.x,-a.y),Vector2(a.x,a.y),Vector2(b.x,b.y)]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(point.x*.35,point.y*.7))
			surface.add_vertex(Vector3(point.x,.10,point.y))
	var deck := MeshInstance3D.new()
	deck.name = "DryInnerDeck"
	deck.mesh = surface.commit()
	hull.add_child(deck)
	for x in [-1.12,-.56,.56,1.12]:
		var seam := MeshInstance3D.new()
		seam.name = "InnerDeckJoint"
		var strip := BoxMesh.new()
		strip.size = Vector3(.012,.003,.72 if absf(x)>1.0 else .96)
		seam.mesh = strip
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(.25,.14,.075)
		seam.material_override = dark
		seam.position = Vector3(x,.102,0)
		hull.add_child(seam)

func seat_world() -> Vector3:
	return to_global(Vector3(0,0.208,0))

func paddle_grip_world(side: String) -> Vector3:
	if paddle == null: return seat_world()
	var socket_name := "socket_paddle_left_hand" if side == "l" else "socket_paddle_right_hand"
	var socket: Node3D = paddle.find_child(socket_name,true,false)
	return socket.global_position if socket != null else paddle.global_position

func paddle_blade_world() -> Vector3:
	if paddle == null: return global_position
	var socket: Node3D = paddle.find_child("socket_paddle_blade_tip",true,false)
	return socket.global_position if socket != null else paddle.global_position

func paddle_rod_world_axis() -> Vector3:
	return paddle.global_basis.x.normalized() if paddle != null else global_basis.x

func can_board(actor: CharacterBody3D) -> bool:
	if rider != null or actor.get_meta("climbing",false): return false
	return actor.global_position.distance_to(seat_world()) < 5.0

func board(actor: CharacterBody3D) -> bool:
	if not can_board(actor): return false
	rider = actor
	saved_layer = actor.collision_layer
	saved_mask = actor.collision_mask
	actor.collision_layer = 0
	actor.collision_mask = 0
	actor.set_meta("mounted_vehicle",self)
	actor.is_swimming = false
	actor.velocity = Vector3.ZERO
	actor.survival.set_sprinting(false)
	var visual: Node = actor.get_node("VisualRoot/CharacterVisual")
	visual.equipment.stowed = true
	visual.equipment._refresh()
	_sync_rider()
	actor.inventory.message_requested.emit("River boat · W/S row · A/D steer · F dismount")
	return true

func _sync_rider() -> void:
	if rider == null: return
	var visual: Node3D = rider.get_node("VisualRoot/CharacterVisual")
	# Align the pelvis to the actual bench, independent of the authored sitting clip's root height.
	var pelvis: int = visual.skeleton.find_bone("pelvis")
	rider.visual_root.global_rotation.y = rotation.y+PI
	var hip_world: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(pelvis).origin)
	rider.global_position += seat_world()+Vector3.UP*0.08-hip_world
	rider.velocity = Vector3.ZERO

func dismount() -> bool:
	if rider == null: return false
	var actor := rider
	var exit_position := Vector3.ZERO
	var found := false
	for side in [-1.0,1.0]:
		var p: Vector3 = global_position + global_basis.x*side*2.0
		var ground: float = layout.height(p.x,p.z)
		p.y = maxf(ground+0.94,-0.1)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = actor.get_node("CollisionShape3D").shape
		query.transform = Transform3D(Basis.IDENTITY,p)
		query.exclude = [get_rid(),actor.get_rid()]
		if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			exit_position = p
			found = true
			break
	if not found:
		actor.inventory.message_requested.emit("No clear space beside the boat")
		return false
	rider = null
	paddle_blend = 0.0
	row_effort = 0.0
	if paddle != null: paddle.transform = paddle_stow
	actor.set_meta("mounted_vehicle",null)
	actor.collision_layer = saved_layer
	actor.collision_mask = saved_mask
	actor.global_position = exit_position
	actor.velocity = Vector3.ZERO
	return true

func _physics_process(delta: float) -> void:
	var throttle: float = 0
	var steer: float = 0
	if rider != null and not rider.inventory_ui.is_open() and not rider.get_meta("map_open",false):
		throttle = Input.get_axis("move_backward","move_forward")
		steer = Input.get_axis("move_right","move_left")
		survival_pause()
	speed = move_toward(speed,throttle*4.2,delta*1.8)
	rotation.y += steer*delta*0.7*clampf(absf(speed),0,1)
	velocity = -global_basis.z*speed
	var next: Vector3 = position+velocity*delta
	var safe := absf(next.z)<Layout.HALF-10
	# Check the bow, stern and beam draft, not only the centre, before entering shallow water.
	for offset in [Vector3(0,0,-2.1),Vector3(0,0,2.1),Vector3(0.7,0,0),Vector3(-0.7,0,0)]:
		var p: Vector3 = next+global_basis*offset
		safe = safe and layout.height(p.x,p.z)<-0.42
	if safe: move_and_slide()
	else:
		speed = 0
		velocity = Vector3.ZERO
	position.y = 0.03
	row_effort = move_toward(row_effort,absf(throttle),delta*3.5)
	paddle_blend = move_toward(paddle_blend,1.0 if rider != null else 0.0,delta*3.5)
	if row_effort > .05:
		row_phase = fmod(row_phase+delta*4.8*signf(throttle if absf(throttle)>.05 else speed),TAU)
	if paddle != null:
		# The existing paddle pivots across the beam; a pitch cycle dips its blade into the river.
		var stroke := sin(row_phase)*row_effort
		var dip := cos(row_phase)*row_effort
		var row_transform := Transform3D(Basis.from_euler(Vector3(0,PI*.5+.22*stroke,-.14-.10*dip)),Vector3(.20,.60,-.24))
		paddle.transform = paddle_stow.interpolate_with(row_transform,paddle_blend)
	if rider != null: _sync_rider()

func survival_pause() -> void:
	rider.survival.set_sprinting(false)
