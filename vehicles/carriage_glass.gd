extends AnimatableBody3D
var pane: MeshInstance3D
var broken := false
var fragment_root: Node3D
func configure(mesh: MeshInstance3D) -> void:
	pane = mesh
	name = "Breakable"+str(mesh.name)
	collision_layer = 8
	collision_mask = 0
	sync_to_physics = false
	transform = mesh.transform
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mesh.mesh.size
	shape.shape = box
	add_child(shape)
	add_to_group("carriage_glass")

func penetrate_shot(damage: float) -> float:
	if not broken: take_damage(damage)
	return maxf(0.0,damage-5.0)

func take_damage(amount: float) -> void:
	if broken or not is_finite(amount) or amount <= 0: return
	broken = true
	pane.hide()
	collision_layer = 0
	set_meta("broken",true)
	# Bounded cosmetic fragments; no scene-wide particles or permanent bodies.
	fragment_root = Node3D.new()
	get_parent().add_child(fragment_root)
	fragment_root.global_transform = global_transform
	var extent: Vector3 = pane.mesh.size
	for i in 9:
		var shard := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		mesh.size = Vector3(.045,.07,.012)
		shard.mesh = mesh
		shard.material_override = pane.material_override
		fragment_root.add_child(shard)
		shard.position = Vector3(0, float(i%3-1)*.13, float(i/3-1)*.22) if extent.x < .02 else Vector3(float(i%3-1)*.20,float(i/3-1)*.13,0)
		var tween := shard.create_tween().set_parallel(true)
		tween.tween_property(shard,"position",shard.position+Vector3((i%3-1)*.08,-1.1,.1),.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(shard,"rotation",Vector3(i*.31,i*.52,i*.17),.65)
	get_tree().create_timer(.8).timeout.connect(fragment_root.queue_free)
