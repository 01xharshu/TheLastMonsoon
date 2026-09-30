extends Node
## One independently damageable horse with a retained corpse and fall transition.
signal died
var health := 90.0
var dead := false
var model: Node3D
var animation: AnimationPlayer
var hit_body: AnimatableBody3D
var fall_pivot: Node3D
var host: Node3D
var fall_side := 1.0
var death_finished := false

func configure(owner_host: Node3D, visual: Node3D, anim: AnimationPlayer, centre: Vector3, side := 1.0) -> void:
	host = owner_host
	model = visual
	animation = anim
	fall_side = side
	hit_body = preload("res://combat/damage_hit_body.gd").new()
	hit_body.name = "HorseHitBody"
	hit_body.damage_receiver = self
	hit_body.collision_layer = 8
	hit_body.collision_mask = 0
	hit_body.sync_to_physics = false
	host.add_child(hit_body)
	for entry in [[centre+Vector3(0,1.17,0),Vector3(.72,1.02,1.8)],[centre+Vector3(0,1.63,-.95),Vector3(.46,.83,.60)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = entry[1]
		shape.shape = box
		shape.position = entry[0]
		hit_body.add_child(shape)
	add_to_group("horse_vitality")

func take_damage(amount: float) -> void:
	if dead or not is_finite(amount) or amount <= 0.0: return
	health = maxf(0.0,health-amount)
	if health > 0.0: return
	dead = true
	set_meta("dead",true)
	if animation != null: animation.pause()
	died.emit()
	# Pivot at the barrel, not at the hoof origin, to avoid a stiff vertical flip.
	fall_pivot = Node3D.new()
	fall_pivot.name = "HorseFallPivot"
	var parent := model.get_parent() as Node3D
	parent.add_child(fall_pivot)
	fall_pivot.position = model.position+Vector3(0,1.05,0)
	model.reparent(fall_pivot,true)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(fall_pivot,"rotation:z",fall_side*PI*.5,1.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fall_pivot,"position:y",fall_pivot.position.y-.65,1.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_finish_fall)
	# The old upright target no longer matches the corpse; retain a low target.
	for shape in hit_body.get_children(): shape.set_deferred("disabled",true)

func _finish_fall() -> void:
	death_finished = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.65,.60,2.7)
	shape.shape = box
	shape.position = host.to_local(fall_pivot.global_position)+Vector3(fall_side*.4,0,0)
	hit_body.add_child(shape)
