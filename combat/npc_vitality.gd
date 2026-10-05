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
	receive_hit(amount,get_tree().root.find_child("Player",true,false),"weapon")

func receive_hit(amount: float, attacker: Node, kind: String = "weapon") -> bool:
	if dead or not is_finite(amount) or amount <= 0.0: return false
	if actor.get_meta("knocked_out",false) and kind in ["punch","kick","takedown","abuse"]:return false
	if attacker != null and attacker.name == "Player" and actor.get_meta("combat_faction","indian") == "indian": return false
	if attacker != null and attacker.name == "Player":
		get_tree().call_group_flags(SceneTree.GROUP_CALL_DEFERRED,"police_crime_observers","report_assault",actor)
	actor.set_meta("last_attacker",attacker)
	actor.set_meta("last_hit_kind",kind)
	health = maxf(0.0,health-amount)
	if actor.has_method("combat_react"): actor.combat_react("down" if actor.get_meta("knocked_out",false) else "hit" if health > 0 else "fall")
	if health > 0: return true
	if kind in ["punch","kick","takedown","abuse"]:
		health=1.0
		actor.set_meta("knocked_out",true)
		actor.set("movement_enabled",false)
		actor.get_node("BodyCollider/BodyShape").set_deferred("disabled",true)
		return true
	dead = true
	actor.set_meta("knocked_out",false)
	actor.set_meta("dead",true)
	actor.set("movement_enabled",false)
	actor.get_node("BodyCollider/BodyShape").set_deferred("disabled",true)
	died.emit()
	return true

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
