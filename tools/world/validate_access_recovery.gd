extends Node3D
const Door = preload("res://objects/hinged_door.gd")
class Builder extends "res://world/suryagarh/settlements/settlement_builder.gd":
	func _ready() -> void: pass
func _ready() -> void: run.call_deferred()
func run() -> void:
	var world := Node3D.new()
	add_child(world)
	var door := Door.new()
	door.opened = false
	door.position = Vector3(2,0,3)
	door.build(StandardMaterial3D.new())
	door.rotation.y = PI*.5
	world.add_child(door)
	await get_tree().physics_frame
	assert(door.is_inside(door.to_global(Vector3(0,0,-1))))
	assert(not door.is_inside(door.to_global(Vector3(0,0,1))))
	door._time_changed(1,22,0)
	assert(door.locked)
	door.restore_state(true)
	door._time_changed(1,22,1)
	assert(door.opened and not door.moving)
	door.restore_state(false)
	door._time_changed(2,6,0)
	assert(not door.locked and door.moving)
	for frame in 90: await get_tree().physics_frame
	assert(door.opened and not door.moving)
	door.auto_open_at_dawn = false
	door.inside_only = true
	door.restore_state(false)
	door._time_changed(2,22,0)
	door.restore_state(true)
	door._time_changed(2,22,1)
	assert(door.opened and not door.moving)
	# A body occupying the normal opening arc must permit the other swing.
	door.restore_state(false)
	var blocker := CharacterBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = .28
	shape.height = 1.8
	collision.shape = shape
	blocker.add_child(collision)
	world.add_child(blocker)
	blocker.global_position = door.to_global(Vector3(.65,.95,.65))
	await get_tree().physics_frame
	await get_tree().physics_frame
	door.swing_direction = 1.0
	door.set_open(true)
	assert(door.moving and door.swing_direction == -1.0)
	for frame in 90: await get_tree().physics_frame
	assert(door.opened and not door.moving)
	var builder := Builder.new()
	world.add_child(builder)
	builder.plaster = StandardMaterial3D.new()
	builder.ochre = builder.plaster
	builder.wood = builder.plaster
	builder.iron = builder.plaster
	var home := builder.make_building("ShutterHome",Vector2(100,100),Vector2(6,6),false,false,false,true)
	var detail := preload("res://world/suryagarh/settlements/bhairavpur_house_detail.gd").new()
	var palette: Array[Material] = [builder.plaster]
	detail.configure(builder,palette)
	detail._openings(home,Vector2(6,6),1)
	assert(get_tree().get_nodes_in_group("climbable_windows").size() == 2)
	assert(home.has_node("TimberWindowFrameEast/PairedWoodShutters"))
	print("ACCESS RECOVERY: PASS rotated inside/outside, night egress, dawn unlock, shutter egress, alternate swing, actual shutter-home portals")
	world.queue_free()
	for frame in 3: await get_tree().physics_frame
	get_tree().quit()
