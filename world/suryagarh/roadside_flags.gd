extends Node3D
## Owner-made EIC flag markers, outside the road surface and rooted in live collision.
const FLAG = preload("res://assets/props/flags/eic/prop_eic_checkpoint_flag_01.glb")
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const CuttableFlag = preload("res://world/suryagarh/cuttable_flag.gd")
const FLAG_SCALE := 0.55
var layout := Layout.new()
var placements: Array[Node3D] = []
var ready_for_review := false

func _ready() -> void:
	# Wait for the baked terrain and bridge collision to enter the physics space.
	await get_tree().physics_frame
	await get_tree().physics_frame
	for z in [-540.0, -300.0, -80.0, 180.0, 390.0, 590.0]:
		place_flag(Vector2(layout.road_x(z)-5.5,z),"RoadMarker_%s" % int(z))
	var river := layout.river_x(165.0)
	place_flag(Vector2(river-146.0,171.0),"WestBridgeApproach")
	place_flag(Vector2(river+146.0,171.0),"EastBridgeApproach")
	ready_for_review = true

func place_flag(point: Vector2, label: String) -> void:
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x,200,point.y),Vector3(point.x,-20,point.y))
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		push_error("Flag has no supporting ground: " + label)
		return
	var marker := StaticBody3D.new()
	marker.name = label
	marker.set_script(CuttableFlag)
	add_child(marker)
	marker.global_position = hit.position
	marker.set_meta("ground_height",hit.position.y)
	var visual: Node3D = FLAG.instantiate()
	marker.add_child(visual)
	visual.scale = Vector3.ONE * FLAG_SCALE
	marker.bind_visual()
	# The pole base is authored at y=0; cloth extends away from the roadway.
	visual.rotation.y = PI
	for animator in visual.find_children("*", "AnimationPlayer", true, false):
		if animator.has_animation("wind_loop"):
			animator.get_animation("wind_loop").loop_mode = Animation.LOOP_LINEAR
			animator.play("wind_loop")
			animator.seek(float(placements.size())*.31,true)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = .085
	shape.height = 4.5 * FLAG_SCALE
	collision.shape = shape
	collision.position.y = 2.25 * FLAG_SCALE
	marker.add_child(collision)
	placements.append(marker)
