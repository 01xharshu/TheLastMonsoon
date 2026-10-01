extends RefCounted
## Sill-supported traversal of registered, unbarred window apertures.
var active := false
var progress := 0.0
var duration := 3.2
var sill := Vector3.ZERO
var normal := Vector3.ZERO
var tangent := Vector3.ZERO
var start := Vector3.ZERO
var landing := Vector3.ZERO
var saved_mask := 0
var profile := "window"
var body_clearance := .50
var bend_amount := 1.0
var solid := preload("res://player/climb_collision.gd").new()
var surface: RefCounted

func start_ledge(actor: CharacterBody3D, point: Vector3, outward: Vector3, destination: Vector3, height: float) -> bool:
	surface = null
	profile = "low_step" if height<=1.05 else "high_mantle"
	duration = lerpf(1.65,2.8,clampf((height-.55)/1.60,0.0,1.0))
	body_clearance = .22 if profile=="low_step" else .18
	bend_amount = .85 if profile=="low_step" else 1.10
	sill = point
	normal = outward
	tangent = Vector3.UP.cross(normal).normalized()
	landing = destination
	return _begin(actor)

func _begin(actor: CharacterBody3D) -> bool:
	start = actor.global_position
	var centre := Vector3.UP*.30 if profile!="window" else Vector3.ZERO
	var raised := sill+normal*.38+Vector3.UP*body_clearance
	var crossed := sill-normal*.52+Vector3.UP*body_clearance
	if not solid.can_move(actor,start,raised,.9,centre) or not solid.can_move(actor,raised,crossed,.9,centre): return false
	if not solid.can_move(actor,crossed,landing,.9,centre): return false
	progress = 0.0
	active = true
	saved_mask = actor.collision_mask
	# The compact shape follows the crouched torso above the hips; its bottom
	# clears the top while the pose keeps a supporting palm at the edge.
	solid.begin(actor,.9,Vector3.UP*.30 if profile!="window" else Vector3.ZERO)
	actor.velocity = Vector3.ZERO
	actor.survival.set_sprinting(false)
	actor.set_meta("climbing",true)
	actor.visual_root.global_rotation.y = atan2(-normal.x,-normal.z)
	var visual: Node = actor.get_node("VisualRoot/CharacterVisual")
	visual.equipment.stowed = true
	visual.equipment._refresh()
	return true

func try_start(actor: CharacterBody3D) -> bool:
	var forward: Vector3 = actor.visual_root.global_basis.z.normalized()
	for portal in actor.get_tree().get_nodes_in_group("climbable_windows"):
		var point: Vector3 = portal.global_position
		var outward: Vector3 = portal.global_basis.x.normalized()
		if (actor.global_position-point).dot(outward)<0.0: outward = -outward
		var across: Vector3 = Vector3.UP.cross(outward).normalized()
		var offset: Vector3 = actor.global_position-point
		if absf(offset.dot(across))>.65 or offset.dot(outward)<.2 or offset.dot(outward)>1.5: continue
		var sill_height: float = point.y-(actor.global_position.y-.9)
		if forward.dot(-outward)<.65 or sill_height<.45 or sill_height>1.55: continue
		var space := actor.get_world_3d().direct_space_state
		var destination: Vector3 = point-outward*.95
		var floor_query := PhysicsRayQueryParameters3D.create(destination+Vector3.UP*.4,destination-Vector3.UP*2.0)
		floor_query.exclude = [actor.get_rid()]
		var floor_hit := space.intersect_ray(floor_query)
		if floor_hit.is_empty() or floor_hit.normal.y<.7: continue
		destination.y = floor_hit.position.y+.94
		var shape := PhysicsShapeQueryParameters3D.new()
		shape.shape = actor.get_node("CollisionShape3D").shape
		shape.transform = Transform3D(Basis.IDENTITY,destination)
		shape.exclude = [actor.get_rid()]
		if not space.intersect_shape(shape,1).is_empty(): continue
		# Check the open aperture itself, so a newly closed shutter blocks entry.
		var opening := PhysicsRayQueryParameters3D.create(point+Vector3.UP*.45+outward*.6,point+Vector3.UP*.45-outward*.6)
		opening.exclude = [actor.get_rid()]
		if not space.intersect_ray(opening).is_empty(): continue
		sill = point
		profile = "window"
		surface = null
		duration = 3.2
		body_clearance = .50
		bend_amount = 1.0
		normal = outward
		tangent = across
		landing = destination
		if _begin(actor): return true
	return false

func advance(actor: CharacterBody3D, delta: float) -> void:
	var previous_progress := progress
	progress = minf(1.0,progress+delta/duration)
	var raised: Vector3 = sill+normal*.38+Vector3.UP*body_clearance
	var crossed: Vector3 = sill-normal*.52+Vector3.UP*body_clearance
	var destination := actor.global_position
	if progress<.28: destination = start.lerp(raised,smoothstep(0.0,.28,progress))
	elif progress<.80: destination = raised.lerp(crossed,smoothstep(.42,.80,progress))
	else: destination = crossed.lerp(landing,smoothstep(.80,1.0,progress))
	if not solid.move_to(actor,destination,.9):
		progress = previous_progress
		return
	if progress>=1.0 and solid.finish(actor):
		active = false
		actor.collision_mask = saved_mask
		actor.set_meta("climbing",false)

func pose(visual: Node, delta: float) -> void:
	var u := progress
	var weight := 1.0
	if visual.motion_tree != null:
		visual.motion_tree.release_climb(delta)
		visual.motion_tree.advance(delta)
	var crouch := smoothstep(.08,.30,u)*(1.0-smoothstep(.78,1.0,u))
	visual.model.position = Vector3(0,-.9-(.16*crouch if surface!=null else 0.0),0)
	visual.model.rotation.x = .30*crouch*bend_amount
	visual.pose("spine_01",Vector3(.55*crouch*bend_amount,0,0),weight)
	visual.pose("spine_02",Vector3(.25*crouch*bend_amount,0,0),weight)
	if profile!="window": visual.keep_climb_body_outside(normal,sill,sill.y,0.0)
	visual.model.force_update_transform()
	visual.skeleton.force_update_transform()
	visual.skeleton.force_update_all_bone_transforms()
	for side in ["l","r"]:
		var lead: bool = side=="l"
		var lift: float = smoothstep(.12 if lead else .36,.35 if lead else .55,u)*(1.0-smoothstep(.73 if lead else .80,.90 if lead else .95,u))
		visual.pose("thigh_"+side,Vector3(-2.1*lift,0,(.25 if lead else -.25)*lift),weight)
		visual.pose("calf_"+side,Vector3(1.6*lift,0,0),weight)
		visual.pose("foot_"+side,Vector3(-.12*lift,0,0),weight)
		var contact := smoothstep(0.0,.12,u)*(1.0-smoothstep(.65,.84,u))
		# On a solid top, transfer the palm from the rim to a supporting push
		# beside the hips. A window keeps its hands on the sill until release.
		var palm_travel: float = .55*smoothstep(.42,.75,u) if profile!="window" else 0.0
		var palm_point: Vector3 = sill+normal*(.08-palm_travel)+tangent*(-.32 if lead else .32)+Vector3.UP*.03
		if surface != null:
			var palm_hit: Dictionary = surface.contact(sill-normal*(.22+palm_travel)+tangent*(-.32 if lead else .32))
			if not palm_hit.is_empty(): palm_point = palm_hit.position+palm_hit.normal*.03
		var target: Vector3 = visual.skeleton.to_local(palm_point)
		var index: int = visual.skeleton.find_bone("hand_"+side)
		for pass_index in 5:
			var hand: Transform3D = visual.skeleton.get_bone_global_pose(index)
			var palm: Vector3 = hand*visual.equipment.palm_offsets[side]
			visual.equipment._solve_arm(side,palm.lerp(target,contact)-hand.basis*visual.equipment.palm_offsets[side])
		visual.equipment._grasp(side,.18*contact)
		var foot_transfer: float = smoothstep(.30 if lead else .50,.50 if lead else .74,u)
		var foot_lift: float = smoothstep(.12 if lead else .36,.28 if lead else .50,u)
		var foot: Vector3 = sill+normal*lerpf(.65,-.65,foot_transfer)+tangent*(-.22 if lead else .22)
		foot.y = lerpf(start.y-.86,sill.y+.13,foot_lift)
		foot.y = lerpf(foot.y,landing.y-.86,smoothstep(.82,.98,u))
		if surface != null and foot_transfer>.55:
			var foot_hit: Dictionary = surface.contact(foot)
			if not foot_hit.is_empty(): foot.y = maxf(foot.y,foot_hit.position.y+.10)
		visual._horse_foot_contact(side,foot,1.0,visual.skeleton.global_basis.inverse()*-normal)
