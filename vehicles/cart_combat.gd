extends Node
## Damage targets are independent of the broad movement-clearance volumes.
var cart: Node3D
var horses: Array[Node] = []
var horse_animations: Dictionary = {}
var panes: Array[Node] = []

func _ready() -> void:
	cart = get_parent()
	for model in cart.visual_root.get_children():
		if not str(model.name).begins_with("DraftHorse"): continue
		var anim := model.find_child("AnimationPlayer",true,false) as AnimationPlayer
		var health := preload("res://horses/horse_vitality.gd").new()
		health.name = str(model.name)+"Health"
		add_child(health)
		health.configure(cart,model,anim,model.position,-1.0 if model.position.x<0 else 1.0)
		health.died.connect(_horse_died.bind(health))
		horses.append(health)
		if anim != null: horse_animations[anim] = health
	# Mesh-local boxes follow moving doors; panes have independent hit targets.
	var solids := ["CabinFloor","RearSeatBack","FrontSeatBack","LowerDoorPanel","DoorWaistRail","FrontQuarter","RearQuarter","WindowPost","WindowLintel","WindowSill","CabinFrontLower","FrontWindowRail","FrontWindowPost","CabinRear","InteriorCeilingLiner"]
	for mesh in cart.visual_root.find_children("*","MeshInstance3D",true,false):
		if not mesh.mesh is BoxMesh: continue
		var label: String = str(mesh.get_meta("cart_part",mesh.get_meta("part_label",mesh.name)))
		if label in ["SideGlazing","FrontGlazing"]:
			var glass := preload("res://vehicles/carriage_glass.gd").new()
			mesh.get_parent().add_child(glass)
			glass.configure(mesh)
			panes.append(glass)
		elif label in solids:
			var body := AnimatableBody3D.new()
			body.name = "ShotBlock"+label
			body.collision_layer = 8
			body.collision_mask = 0
			body.sync_to_physics = false
			mesh.get_parent().add_child(body)
			body.transform = mesh.transform
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = mesh.mesh.size
			shape.shape = box
			body.add_child(shape)

func can_move() -> bool:
	if horses.is_empty(): return false
	for horse in horses:
		if horse.dead: return false
	return true

func animation_dead(anim: AnimationPlayer) -> bool:
	return horse_animations.has(anim) and horse_animations[anim].dead

func _horse_died(horse: Node) -> void:
	for player in cart.hoof_players: player.stop()
	# Release the fallen horse's traces/rein instead of leaving rigid straps in air.
	for mesh in cart.visual_root.find_children("*","MeshInstance3D",true,false):
		var label := str(mesh.get_meta("cart_part",mesh.get_meta("part_label",mesh.name)))
		if label not in ["BreastStrap","OutsideTrace","InsideTrace","PoleStrap","BreastCollar","CollarToTrace","Rein"]: continue
		var local := cart.to_local(mesh.global_position)
		if horses.size()==1 or signf(local.x)==signf(horse.model.position.x+horse.fall_side*.01): mesh.hide()
