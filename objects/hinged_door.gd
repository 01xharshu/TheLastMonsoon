extends Interactable
## Paired physical leaves: the interaction body stays at the latch while each leaf swings.
var width := 2.6
var height := 2.32
var night_lock := true
@export_range(0, 23) var opening_hour := 6
@export_range(0, 23) var closing_hour := 20
var always_open := false
var inside_only := false
var auto_open_at_dawn := true
var label_name := "door"
var opened := true
var locked := false
var moving := false
var last_night := false
var clock: GameTimeSystem
var motion: Tween
var leaf_pivots: Array[Node3D] = []
var leaf_shapes: Array[CollisionShape3D] = []
var swing_direction := 1.0
var swing := 1.0:
	set(value):
		swing = value
		_apply_swing()
var last_safe_swing := 1.0
var iron: StandardMaterial3D

func build(material: Material) -> void:
	# Callers specify the left jamb; place the prompt at the central latch.
	position.x += width*.5
	interaction_icon = "gate"
	interaction_max_distance = 3.0
	marker_height = height*.18 if inside_only else minf(height*.50,1.22)
	add_to_group("house_doors")
	iron = StandardMaterial3D.new()
	iron.albedo_color = Color(.12,.105,.09)
	iron.metallic = .65
	iron.roughness = .73
	var timber := ShaderMaterial.new()
	timber.shader = preload("res://objects/door_timber.gdshader")
	timber.set_shader_parameter("tint",Color(.27,.16,.085) if width < 4 else Color(.23,.14,.075))
	# Separate boards, a continuous matching collider, and iron fittings on each leaf.
	for side in [-1.0,1.0]:
		var pivot := Node3D.new()
		pivot.name = "LeftLeaf" if side < 0 else "RightLeaf"
		pivot.position.x = side*width*.5
		add_child(pivot)
		leaf_pivots.append(pivot)
		var leaf_width := width*.5
		var count := maxi(4,int(ceil(leaf_width/.26)))
		for board in count:
			var x: float = -side*(float(board)+.5)*leaf_width/count
			_visual(pivot,"TimberPlank",Vector3(x,height*.5,0),Vector3(leaf_width/count-.006,height,.105),timber)
		for y in [height*.18,height*.77]:
			_visual(pivot,"InnerCrossRail",Vector3(-side*leaf_width*.5,y,-.075),Vector3(leaf_width-.04,.13,.055),timber)
			_visual(pivot,"ForgedHingeStrap",Vector3(-side*leaf_width*.35,y,.065),Vector3(leaf_width*.65,.07,.02),iron)
			_visual(pivot,"HingePin",Vector3(-side*.018,y,0),Vector3(.055,.18,.10),iron)
			for rivet in 4:
				_visual(pivot,"StrapRivet",Vector3(-side*(.08+rivet*leaf_width*.17),y,.08),Vector3(.024,.024,.016),iron)
		var brace := _visual(pivot,"InnerDiagonalBrace",Vector3(-side*leaf_width*.5,height*.47,-.084),Vector3(sqrt(pow(leaf_width*.80,2)+pow(height*.52,2)),.10,.045),timber)
		brace.rotation.z = side*atan2(height*.52,leaf_width*.80)
		_visual(pivot,"LatchPlate",Vector3(-side*(leaf_width-.12),(height*.18 if inside_only else minf(height*.52,1.25)),.075),Vector3(.13,.24,.025),iron)
		# A rounded iron pull, rather than a painted mark on the leaf.
		var pull := MeshInstance3D.new()
		pull.name = "IronPullRing"
		var ring := TorusMesh.new()
		ring.inner_radius = .037
		ring.outer_radius = .055
		ring.rings = 16
		ring.ring_segments = 8
		pull.mesh = ring
		pull.material_override = iron
		pull.rotation.x = PI*.5
		pull.position = Vector3(-side*(leaf_width-.12),(height*.18 if inside_only else minf(height*.50,1.22)),.115)
		pivot.add_child(pull)
		var inner_pull := pull.duplicate() as MeshInstance3D
		inner_pull.name="InteriorPullRing"
		inner_pull.position.z=-.145
		pivot.add_child(inner_pull)
		var collision := CollisionShape3D.new()
		collision.name = "LeftLeafCollision" if side < 0 else "RightLeafCollision"
		var shape := BoxShape3D.new()
		shape.size = Vector3(leaf_width,height,.14)
		collision.shape = shape
		add_child(collision)
		leaf_shapes.append(collision)
		_visual(pivot,"InteriorLatchBar",Vector3(-side*(leaf_width-.18),(height*.18 if inside_only else minf(height*.52,1.25)),-.11),Vector3(.34,.07,.05),iron)
	for pivot in leaf_pivots: _batch_leaf(pivot)
	rotation.y = 0
	swing = 1.0 if opened else 0.0
	last_safe_swing = swing
	_label()

func _batch_leaf(pivot: Node3D) -> void:
	# Boards and ironwork move rigidly with the hinge. Preserve that pivot and
	# the separate collision leaf, but submit one surface per shared material.
	var surfaces: Dictionary = {}
	for child in pivot.get_children():
		if not child is MeshInstance3D: continue
		var material: Material = child.material_override
		if not surfaces.has(material):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[material] = surface
		for index in child.mesh.get_surface_count():
			var source: Mesh = child.mesh
			var source_index: int = index
			if material is ShaderMaterial:
				# Grain uses each board's original coordinates. Keep those in the
				# second UV channel while positions are baked into hinge space.
				var arrays: Array = child.mesh.surface_get_arrays(index)
				var coordinates := PackedVector2Array()
				for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
					coordinates.append(Vector2(vertex.x,vertex.y))
				arrays[Mesh.ARRAY_TEX_UV2] = coordinates
				var board := ArrayMesh.new()
				board.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				source = board
				source_index = 0
				material.set_shader_parameter("batched_piece_coordinates",true)
			surfaces[material].append_from(source,source_index,child.transform)
		if child.name in ["IronPullRing","InteriorPullRing"]:
			var anchor := Marker3D.new()
			anchor.name = child.name
			anchor.transform = child.transform
			pivot.remove_child(child)
			pivot.add_child(anchor)
		child.free()
	var merged := ArrayMesh.new()
	for material: Material in surfaces:
		surfaces[material].set_material(material)
		surfaces[material].commit(merged)
	var visual := MeshInstance3D.new()
	visual.name = "BatchedLeafBoardsAndIronwork"
	visual.mesh = merged
	pivot.add_child(visual)

func _visual(parent: Node3D,label: String,at: Vector3,size: Vector3,material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	return mesh

func _leaf_transform(index: int,amount: float) -> Transform3D:
	var side := -1.0 if index == 0 else 1.0
	var basis := Basis(Vector3.UP,side*amount*PI*.5*swing_direction)
	var hinge := Vector3(side*width*.5,0,0)
	return Transform3D(basis,hinge+basis*Vector3(-side*width*.25,height*.5,0))

func _apply_swing() -> void:
	for i in leaf_pivots.size():
		var side := -1.0 if i == 0 else 1.0
		leaf_pivots[i].rotation.y = side*swing*PI*.5*swing_direction
		leaf_shapes[i].transform = _leaf_transform(i,swing)

func _ready() -> void:
	_bind_clock.call_deferred()

func _bind_clock() -> void:
	if get_tree().current_scene == null: return
	clock = get_tree().current_scene.find_child("GameTimeSystem",true,false) as GameTimeSystem
	if clock != null:
		clock.time_changed.connect(_time_changed)
		_time_changed(clock.current_day,clock.current_hour,clock.current_minute)

func hours_allow_entry(hour: int) -> bool:
	if opening_hour == closing_hour: return true
	if opening_hour < closing_hour:
		return hour >= opening_hour and hour < closing_hour
	return hour >= opening_hour or hour < closing_hour

func _time_changed(_day: int,hour: int,_minute: int) -> void:
	var night := not hours_allow_entry(hour)
	locked = night and night_lock and not always_open
	if night != last_night or (locked and opened):
		last_night = night
		if locked or auto_open_at_dawn: set_open(not locked)
	_label()

func _character_in_leaf(amount: float) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width*.5+.04,height+.04,.19)
	query.shape = shape
	query.exclude = [get_rid()]
	for index in 2:
		query.transform = global_transform*_leaf_transform(index,amount)
		for hit in get_world_3d().direct_space_state.intersect_shape(query,64):
			if hit.collider is CharacterBody3D or hit.collider is AnimatableBody3D:
				if get_meta("debug_sweep",false): print("SWEEP OCCUPIED ",hit.collider.get_path()," amount ",amount," actor at ",hit.collider.global_position)
				return true
	return false

func _physics_process(_delta: float) -> void:
	if not moving: return
	if _character_in_leaf(swing):
		motion.kill()
		swing = last_safe_swing
		moving = false
		opened = swing > .5
		_label()
	else:
		last_safe_swing = swing

func interact(player: CharacterBody3D) -> void:
	if moving: return
	var inside: bool = get_parent().to_local(player.global_position).z < position.z
	if (locked or inside_only) and not inside: return
	var action = player.get_node_or_null("DoorLatchAction")
	if action == null:
		action=preload("res://player/door_latch_action.gd").new()
		action.name="DoorLatchAction"
		player.add_child(action)
	action.begin(self)

func interaction_anchor() -> Vector3:
	if opened and is_inside_tree() and get_tree().current_scene != null:
		var player = get_tree().current_scene.get_node_or_null("Player")
		if player != null:
			var pull := nearest_pull(player.global_position)
			if pull != null: return pull.global_position
	return super.interaction_anchor()

func nearest_pull(at: Vector3) -> Node3D:
	var nearest: Node3D
	var distance := INF
	for pivot in leaf_pivots:
		for label in ["IronPullRing","InteriorPullRing"]:
			var pull = pivot.get_node(label)
			var gap: float = pull.global_position.distance_to(at)
			if gap < distance: nearest=pull; distance=gap
	return nearest

func set_open(value: bool) -> void:
	if moving or (value == opened and is_equal_approx(swing,1.0 if value else 0.0)): return
	var target := 1.0 if value else 0.0
	# Check the whole swept path before moving, then check again during the swing.
	for sample in 13:
		if _character_in_leaf(lerpf(swing,target,float(sample)/12.0)): return
	opened = value
	moving = true
	WorldAudio.play_at("door",global_position)
	last_safe_swing = swing
	motion = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(self,"swing",target,1.1 if width < 4 else 2.2)
	motion.finished.connect(func(): moving = false; _label())
	_label()

func _label() -> void:
	interaction_text = "Latched for the night" if locked and not opened else ("Close "+label_name if opened else "Open "+label_name+(" · latch inside" if inside_only else ""))

func restore_state(value: bool) -> void:
	if motion != null and motion.is_valid(): motion.kill()
	moving=false
	opened=value
	swing=1.0 if value else 0.0
	last_safe_swing=swing
	_label()
