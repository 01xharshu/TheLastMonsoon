extends RefCounted
## Borrow the real village bullock cart; preserve its gameplay placement after the cut.
const DURATION := 23.0
const SPEED := 1.6
const START := Vector2(-260,237)
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
var layout := Layout.new()
var opening: Node3D
var cart: Node3D
var original_transform := Transform3D.IDENTITY
var original_speed := 0.0
var original_boarding_physics := true
var original_wheels: Array[Vector3] = []
var age := 0.0
var active := false
var wheel_camera_position := Vector3.ZERO
var wheel_camera_target := Vector3.ZERO
var footfall_age := 0.0
var gathering_sound: AudioStreamPlayer3D
var gathering: Node
var gathering_physics := true
var people: Array[Dictionary] = []

func begin(sequence: Node3D) -> bool:
	opening = sequence
	cart = opening.world.get_node_or_null("LiveCarts/VillageBullockCart")
	if cart == null:
		push_warning("Opening cart passage needs the authored village bullock cart")
		return false
	original_transform = cart.global_transform
	original_speed = cart.boarding.speed
	original_boarding_physics = cart.boarding.is_physics_processing()
	original_wheels.clear()
	for wheel in cart.wheels: original_wheels.append(wheel.rotation)
	cart.boarding.set_physics_process(false)
	cart.rotation.y = PI
	cart.global_position = position_at(0.0)
	cart.boarding.speed = SPEED
	age = 0.0
	active = true
	var wheel_at := position_at(8.0)+Vector3(1.05,.68,-2.55)
	wheel_camera_position = wheel_at+Vector3(2.15,.22,-1.4)
	wheel_camera_target = wheel_at+Vector3(-.7,.18,2.4)
	gathering_sound = AudioStreamPlayer3D.new()
	gathering_sound.name = "OpeningGatheringFireAudio"
	gathering_sound.stream = preload("res://systems/audio_edges.gd").prepare(preload("res://audio/ambience/fire.wav"))
	gathering_sound.volume_db = -19.0
	gathering_sound.max_distance = 38.0
	gathering_sound.unit_size = 5.0
	opening.add_child(gathering_sound)
	gathering_sound.global_position = Vector3(-265,layout.height(-265,259)+.7,259)
	gathering_sound.play()
	_stage_gathering()
	update(0.0)
	return true

func position_at(seconds: float) -> Vector3:
	var z := START.y+seconds*SPEED
	return Vector3(START.x,layout.height(START.x,z),z)

func update(delta: float) -> void:
	if not active: return
	age = minf(age+delta,DURATION)
	cart.global_position = position_at(age)
	cart.boarding.speed = SPEED
	cart.set_forward_motion(SPEED,delta)
	for record in people:
		var person: Node3D = record.actor
		person.travel_speed = 0.0
		person._set_animation(&"idle",delta)
		var member: Dictionary = record.member
		if member.get("lantern") != null: member.lantern.update(delta,true)
		elif member.get("torch") != null: member.torch.update(delta,true)
	footfall_age += delta
	if footfall_age >= .48:
		footfall_age = fmod(footfall_age,.48)
		cart._play_cart_hoof()
	var sun := opening.world.get_node_or_null("Sun") as DirectionalLight3D
	var moon := opening.world.get_node_or_null("Moon") as DirectionalLight3D
	if sun != null: sun.light_energy = 0.0
	if moon != null: moon.light_energy = .32
	opening.environment.ambient_light_energy = .18
	opening.subtitle.text = "BHAIRAVPUR · NIGHT" if age < 6.5 else ""
	if age < 8.0:
		var at := cart.global_position
		opening.camera.fov = 54.0
		opening.camera.global_position = Vector3(-237,at.y+24.0,at.z-19.0)
		opening.camera.look_at(Vector3(-266,at.y+.6,at.z+11))
		opening.shade.color = Color(0,0,0,maxf(1.0-smoothstep(0.0,1.2,age),smoothstep(6.6,7.8,age)))
	else:
		# Camera holds in world space while the cart advances out of its foreground.
		opening.camera.fov = 48.0
		opening.camera.global_position = wheel_camera_position
		opening.camera.look_at(wheel_camera_target)
		opening.shade.color = Color(0,0,0,maxf(1.0-smoothstep(8.15,9.1,age),smoothstep(20.5,22.8,age)))
	opening.score.volume_db = lerpf(-14.0,-24.0,smoothstep(0,3,age))
	if gathering_sound != null and not gathering_sound.playing and age < 20.5: gathering_sound.play()

func finish() -> void:
	if not active: return
	active = false
	_restore_gathering()
	if is_instance_valid(gathering_sound):
		gathering_sound.stop()
		gathering_sound.queue_free()
		gathering_sound = null
	if is_instance_valid(cart):
		cart.global_transform = original_transform
		cart.boarding.speed = original_speed
		cart.set_forward_motion(original_speed,0.0)
		cart.boarding.set_physics_process(original_boarding_physics)
		for index in mini(cart.wheels.size(),original_wheels.size()): cart.wheels[index].rotation = original_wheels[index]
		for sound in cart.hoof_players: sound.stop()
	opening.subtitle.text = ""
	opening.environment.ambient_light_energy = 0.0

func _stage_gathering() -> void:
	gathering = opening.world.find_child("FireGatheringResidents",true,false)
	if gathering == null: return
	if gathering.members.size() < 2: gathering._physics_process(.1)
	gathering_physics = gathering.is_physics_processing()
	gathering.set_physics_process(false)
	people.clear()
	for index in gathering.members.size():
		var member: Dictionary = gathering.members[index]
		var person: Node3D = member.actor
		if person.get_meta("dead",false) or person.get_meta("knocked_out",false): continue
		var activity: Node = member.activity
		people.append({"actor":person,"transform":person.global_transform,"activity":activity,"physics":activity.is_physics_processing(),"speed":person.travel_speed,"member":member,"work_blend":person.animation_tree.get("parameters/daily_work/blend_amount")})
		activity.set_physics_process(false)
		person.animation_tree.set("parameters/daily_work/blend_amount",0.0)
		var angle := .35+index*PI*.5
		var center: Vector3 = gathering.fire.global_position
		var point := center+Vector3(cos(angle)*2.3,0,sin(angle)*2.3)
		point.y = layout.height(point.x,point.z)
		person.global_position = point
		person.global_rotation.y = atan2(center.x-point.x,center.z-point.z)
		person.travel_speed = 0.0
		person._set_animation(&"idle",1.0)

func _restore_gathering() -> void:
	for record in people:
		if not is_instance_valid(record.actor): continue
		record.actor.global_transform = record.transform
		record.actor.travel_speed = record.speed
		record.actor.animation_tree.set("parameters/daily_work/blend_amount",record.work_blend)
		if is_instance_valid(record.activity): record.activity.set_physics_process(record.physics)
	people.clear()
	if is_instance_valid(gathering): gathering.set_physics_process(gathering_physics)
	gathering = null
