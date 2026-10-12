extends StaticBody3D
## Event-driven fracture; bounded animation and twelve retained debris sets.
signal broken(reason: String)
static var debris_sets: Array[WeakRef] = []
var is_broken := false
var vessel_size := 1.0
var unfired := false
var visual_root: Node3D
var nearby: Array[CharacterBody3D] = []
var fragments: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("fragile_household_prop")
	add_to_group("solid_period_prop")
	set_physics_process(false)
	_configure_visuals.call_deferred()
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	# Allow one sprint frame before slide collision discards incoming velocity.
	shape.radius = .24*vessel_size+.32
	shape.height = .50*vessel_size
	collision.shape = shape
	collision.position.y = shape.height*.5
	area.add_child(collision)
	add_child(area)
	area.body_entered.connect(func(body):
		if is_broken: return
		if body is CharacterBody3D and (body.is_in_group("player") or body.name == "Player"):
			nearby.append(body)
			set_physics_process(true))
	area.body_exited.connect(func(body):
		if not body is CharacterBody3D: return
		nearby.erase(body)
		if nearby.is_empty(): set_physics_process(false))

func _configure_visuals() -> void:
	var visual: Node3D = visual_root if visual_root else self
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if mesh.name == "StoredWater" else GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		mesh.visibility_range_end = 90
		mesh.visibility_range_end_margin = 10

func _physics_process(_delta: float) -> void:
	for body in nearby:
		if is_instance_valid(body) and Vector2(body.velocity.x,body.velocity.z).length() >= 4.8:
			_break.call_deferred("running impact")
			return

func take_damage(amount: float) -> void:
	if amount > 0 and not is_broken: _break.call_deferred("damage")

func _break(reason: String) -> void:
	if is_broken: return
	is_broken = true
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	for node in find_children("*","Area3D",true,false): node.monitoring = false
	var debris := Node3D.new()
	debris.name = "BrokenFragments"
	add_child(debris)
	debris_sets.append(weakref(debris))
	while debris_sets.size() > 12:
		var old = debris_sets.pop_front().get_ref()
		if is_instance_valid(old): old.queue_free()
	var visual: Node3D = visual_root if visual_root else self
	var meshes := visual.find_children("*","MeshInstance3D",true,false)
	for source: MeshInstance3D in meshes:
		if source.name == "StoredWater" or str(source.name).ends_with("Foot") or source.mesh is QuadMesh:
			source.hide()
			continue
		if not source.visible: continue
		var transform := global_transform.affine_inverse()*source.global_transform
		var groups: Array = [[],[],[],[],[],[],[],[]]
		var faces := source.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var centre := transform*((faces[i]+faces[i+1]+faces[i+2])/3.0)
			var sector := clampi(int((atan2(centre.z,centre.x)+PI)/TAU*4),0,3)
			if centre.y > .22*vessel_size: sector += 4
			for j in 3: groups[sector].append(transform*faces[i+j])
		var mat: Material = source.material_override
		if mat == null: mat = source.get_active_material(0)
		for sector in 8:
			if groups[sector].is_empty(): continue
			var centre := Vector3.ZERO
			for point: Vector3 in groups[sector]: centre += point
			centre /= groups[sector].size()
			var shard := MeshInstance3D.new()
			shard.mesh = _fragment_mesh(groups[sector],centre)
			shard.material_override = mat
			shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
			shard.visibility_range_end = 60
			shard.visibility_range_end_margin = 5
			debris.add_child(shard)
			var angle := TAU*float(sector)/8.0
			var rotation_ := Vector3(1.4,angle,.25)
			var end := centre+Vector3(cos(angle),0,sin(angle))*(.15 if unfired else .45)*vessel_size
			var from := to_global(Vector3(end.x,maxf(centre.y,.05)+.05,end.z))
			var ray := PhysicsRayQueryParameters3D.create(from,from-Vector3.UP*5)
			var excluded: Array[RID] = []
			for prop in get_tree().get_nodes_in_group("fragile_household_prop"): excluded.append(prop.get_rid())
			for actor in get_tree().current_scene.find_children("*","CharacterBody3D",true,false): excluded.append(actor.get_rid())
			if visual is CollisionObject3D: excluded.append(visual.get_rid())
			ray.exclude = excluded
			var hit := get_world_3d().direct_space_state.intersect_ray(ray)
			var low := 0.0
			for point: Vector3 in shard.mesh.get_faces(): low = minf(low,(Basis.from_euler(rotation_)*point).y)
			end.y = (to_local(hit.position).y if not hit.is_empty() else 0.0)-low+.008
			fragments.append({"mesh":shard,"start":centre,"end":end,"rotation":rotation_})
			source.hide()
	var tween := create_tween()
	tween.tween_method(_animate,0.0,1.0,.65 if not unfired else .35)
	broken.emit(reason)

func _inner(point: Vector3) -> Vector3:
	return point-Vector3(point.x,0,point.z).normalized()*.012*vessel_size

func _fragment_mesh(points: Array,centre: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges: Dictionary = {}
	for i in range(0,points.size(),3):
		for j in 3: st.add_vertex(points[i+j]-centre)
		for j in [2,1,0]: st.add_vertex(_inner(points[i+j])-centre)
		for j in 3:
			var a: Vector3 = points[i+j]
			var b_: Vector3 = points[i+(j+1)%3]
			var key := str(a)+"|"+str(b_) if str(a)<str(b_) else str(b_)+"|"+str(a)
			if edges.has(key): edges[key].count += 1
			else: edges[key] = {"a":a,"b":b_,"count":1}
	for edge in edges.values():
		if edge.count != 1: continue
		for point: Vector3 in [edge.a,_inner(edge.a),edge.b,edge.b,_inner(edge.a),_inner(edge.b)]: st.add_vertex(point-centre)
	st.generate_normals()
	st.index()
	return st.commit()

func _animate(t: float) -> void:
	for fragment in fragments:
		var shard = fragment.mesh
		if not is_instance_valid(shard): continue
		shard.position = fragment.start.lerp(fragment.end,t)+Vector3.UP*sin(PI*t)*(.08 if unfired else .30)
		shard.rotation = fragment.rotation*t
