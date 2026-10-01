extends Node
signal died
var health := 75.0
var dead := false
var actor: Node3D
var hit_body: AnimatableBody3D
func _ready() -> void:
	actor = get_parent()
	hit_body = preload("res://combat/damage_hit_body.gd").new()
	hit_body.name = "CombatHitBody"
	hit_body.damage_receiver = self
	hit_body.collision_layer = 8
	hit_body.collision_mask = 0
	hit_body.sync_to_physics = false
	actor.add_child(hit_body)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .24
	capsule.height = .95
	shape.shape = capsule
	shape.position.y = 1.15
	hit_body.add_child(shape)
	var head_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .18
	head_shape.shape = sphere
	hit_body.add_child(head_shape)
	# Existing body collision must also forward ground-level shots.
	var body: AnimatableBody3D = actor.get_node("BodyCollider")
	body.set_script(preload("res://combat/damage_hit_body.gd"))
	body.set("damage_receiver",self)

func take_damage(amount: float) -> void:
	if dead or not is_finite(amount) or amount <= 0: return
	get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED,"police_crime_observers","report_assault",actor)
	health = maxf(0.0,health-amount)
	if health > 0: return
	dead = true
	actor.set_meta("dead",true)
	actor.set_process(false)
	var tree: AnimationTree = actor.get("animation_tree")
	if tree != null: tree.active = false
	var animation: AnimationPlayer = actor.get("animation_player")
	if animation != null: animation.pause()
	var coach: Node3D = actor.get_meta("seated_coach",null)
	if is_instance_valid(coach):
		actor.reparent(coach,true)
		var skeleton: Skeleton3D = actor.get("_skeleton")
		var spine := skeleton.find_bone("spine_02")
		var head := skeleton.find_bone("head")
		var axes: Dictionary = actor.get("_pitch_axes")
		for entry in [[spine,"spine_02",.65],[head,"head",.45]]:
			if entry[0] < 0: continue
			var start := skeleton.get_bone_pose_rotation(entry[0])
			var end := start*Quaternion(axes[entry[1]],entry[2])
			create_tween().tween_method(func(q: Quaternion): skeleton.set_bone_pose_rotation(entry[0],q),start,end,.8)
	else:
		create_tween().set_parallel(true).tween_property(actor,"rotation:x",PI*.5,1.0)
		actor.get_node("BodyCollider/BodyShape").set_deferred("disabled",true)
	died.emit()

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(hit_body): return
	var skeleton: Skeleton3D = actor.get("_skeleton")
	if skeleton == null: return
	var bone := skeleton.find_bone("spine_02")
	if bone < 0: return
	var centre := skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)
	hit_body.get_child(0).global_position = centre
	var head := skeleton.find_bone("head")
	if head >= 0: hit_body.get_child(1).global_position = skeleton.to_global(skeleton.get_bone_global_pose(head).origin)+Vector3.UP*.08
	hit_body.force_update_transform()
