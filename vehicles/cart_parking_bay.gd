extends Node3D
## Fixed, terrain-following cart standing with collision-checked docking.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
var size := Vector2(6,12)
var owner_cart: Node3D
var occupant: Node3D
var docked := false
var refresh_elapsed := 0.0
var standing_heading := 0.0

func configure(cart: Node3D, label: String) -> void:
	owner_cart = cart
	standing_heading = cart.global_rotation.y
	global_position = cart.global_position
	global_rotation.y = standing_heading
	set_meta("parking_label",label)
	set_meta("parking_capacity",1)
	set_meta("parking_size",size)
	cart.set_meta("parking_bay",self)

func _ready() -> void:
	add_to_group("cart_parking_bays")
	_build_standing.call_deferred()

func _build_standing() -> void:
	# A single terrain-following dirt surface adds one draw, no invisible collider.
	var layout := Layout.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in 6:
		for x in 3:
			var a := Vector3(-size.x*.5+x*2.0,0,-size.y*.5+z*2.0)
			for offset in [Vector3.ZERO,Vector3(2,0,0),Vector3(0,0,2),Vector3(2,0,0),Vector3(2,0,2),Vector3(0,0,2)]:
				var at: Vector3 = to_global(a+offset)
				var ray := PhysicsRayQueryParameters3D.create(at+Vector3.UP*2,at-Vector3.UP*3)
				if is_instance_valid(owner_cart): ray.exclude = owner_cart.boarding._vehicle_exclusions()
				var hit := get_world_3d().direct_space_state.intersect_ray(ray)
				at.y = (hit.position.y if not hit.is_empty() else layout.height(at.x,at.z))+.012
				surface.add_vertex(to_local(at))
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "CompactedStanding"
	mesh.mesh = surface.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://vehicles/cart_standing_ground.gdshader")
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.visibility_range_end = 100
	add_child(mesh)
	refresh_occupancy()

func _physics_process(delta: float) -> void:
	refresh_elapsed += delta
	if refresh_elapsed < .5: return
	refresh_elapsed = 0
	refresh_occupancy()

func refresh_occupancy() -> void:
	occupant = null
	docked = false
	for cart in get_tree().get_nodes_in_group("cart_parking_vehicles"):
		if _overlaps_vehicle(cart):
			# A second vehicle takes precedence over the owner so docking cannot
			# accept a bay merely because its own centre also lies inside it.
			if occupant == null or cart != owner_cart: occupant = cart
			if cart != owner_cart: break
	if occupant == owner_cart:
		docked = Vector2(owner_cart.global_position.x-global_position.x,owner_cart.global_position.z-global_position.z).length() < .6 and absf(angle_difference(owner_cart.global_rotation.y,standing_heading)) < .15
	set_meta("parking_occupied",occupant != null)
	set_meta("parking_docked",docked)

func _overlaps_vehicle(cart: Node3D) -> bool:
	var local: Vector3 = to_local(cart.global_position)
	if absf(local.y) >= 2: return false
	if not "boarding" in cart:
		return absf(local.x) < size.x*.5 and absf(local.z) < size.y*.5
	var polygon := PackedVector2Array([Vector2(-size.x*.5,-size.y*.5),Vector2(size.x*.5,-size.y*.5),Vector2(size.x*.5,size.y*.5),Vector2(-size.x*.5,size.y*.5)])
	for collision in cart.boarding.clearance_shapes:
		if not collision.shape is BoxShape3D: continue
		var half: Vector3 = collision.shape.size*.5
		var footprint := PackedVector2Array()
		for corner in [Vector3(-half.x,0,-half.z),Vector3(half.x,0,-half.z),Vector3(half.x,0,half.z),Vector3(-half.x,0,half.z)]:
			var at: Vector3 = to_local(collision.to_global(corner))
			footprint.append(Vector2(at.x,at.z))
		if not Geometry2D.intersect_polygons(polygon,footprint).is_empty(): return true
	return false

func try_dock(cart: Node3D) -> bool:
	refresh_occupancy()
	if cart != owner_cart or (occupant != null and occupant != cart): return false
	if Vector2(cart.global_position.x-global_position.x,cart.global_position.z-global_position.z).length() > .6: return false
	if absf(angle_difference(cart.global_rotation.y,standing_heading)) > .15: return false
	var previous := cart.global_transform
	cart.global_rotation.y = standing_heading
	if not cart.boarding._clearance_at(global_position):
		cart.global_transform = previous
		return false
	cart.global_position = global_position
	cart.boarding.speed = 0
	cart.set_forward_motion(0,0)
	cart.boarding.collision_body.force_update_transform()
	refresh_occupancy()
	return docked
