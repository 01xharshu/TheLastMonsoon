extends "res://tools/world/validate_architecture_navigation.gd"
class FootTargets extends RefCounted:
	var ankle_height: Dictionary={"l":.08,"r":.08}
class MotionProbe extends ClearanceProbe:
	var foot_plant:=FootTargets.new()
	var travel_speed:=0.0
	func _set_animation(_state: StringName,_delta: float) -> void:pass
class Manager extends Node3D:
	var JOBS: Dictionary={"fixture":{"goal":"receiver"}}
	var targets: Dictionary={}
func solid(world: Node3D,at: Vector3,size: Vector3) -> StaticBody3D:
	var body:=StaticBody3D.new();world.add_child(body);body.position=at
	var shape:=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=size;body.add_child(shape)
	return body
func run() -> void:
	var world:=Node3D.new();root.add_child(world);current_scene=world
	solid(world,Vector3(0,-.1,0),Vector3(20,.2,20))
	var step:=solid(world,Vector3(0,.12,2),Vector3(3,.24,1))
	var actor:=MotionProbe.new();world.add_child(actor)
	var manager:=Manager.new();world.add_child(manager)
	var endpoint:=StaticBody3D.new();endpoint.collision_layer=0;world.add_child(endpoint);manager.targets.receiver=endpoint
	var delivery:=preload("res://world/suryagarh/errands/delivery_handover.gd").new()
	delivery.manager=manager;delivery.receiver=actor;delivery.request="fixture";delivery.phase="returning"
	world.add_child(delivery);delivery.set_process(false);delivery.set_physics_process(false)
	await sync()
	for sample in 45:
		delivery._step(Vector3(0,0,.05),1.0/60)
		await physics_frame
	check(actor.position.z>2.0 and absf(actor.position.y-.24)<.01,"receiver crosses supported24cm riser with retained capsule")
	actor.position=Vector3.ZERO;actor.body_collider.force_update_transform()
	var ceiling:=solid(world,Vector3(0,1.95,2),Vector3(3,.3,2))
	await sync()
	for sample in 45:
		delivery._step(Vector3(0,0,.05),1.0/60)
		await physics_frame
	check(actor.position.z<1.5,"step cannot bypass blocked head clearance")
	ceiling.queue_free();step.queue_free();await sync()
	actor.position=Vector3.ZERO;actor.body_collider.force_update_transform()
	solid(world,Vector3(0,1.5,2),Vector3(3,3,1))
	await sync()
	for sample in 45:
		delivery._step(Vector3(0,0,.05),1.0/60)
		await physics_frame
	check(actor.position.z<1.5,"receiver cannot climb a tall wall")
	world.queue_free();current_scene=null
	for frame in 3:await process_frame
	print("DELIVERY STEP CONTACT ",JSON.stringify({"checks":count,"status":"PASS" if failures.is_empty() else "FAIL","failures":failures,"scope":"physics-only query fixture, no animation/clothing approval"}))
	root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
