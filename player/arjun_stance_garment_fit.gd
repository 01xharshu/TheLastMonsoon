extends RefCounted
## Refit existing garments; preserve body geometry and the editable source rig.
const CACHE_DIR := "res://characters/arjun/stance_fit"
const INPUTS := ["res://characters/arjun/arjun.glb","res://characters/arjun/arjun_riding_cloth.glb","res://player/arjun_clothing.gd","res://player/arjun_trouser_fit.gd","res://player/arjun_stance_garment_fit.gd"]
static func fingerprint() -> String:
	var value := ""
	for path in INPUTS: value += FileAccess.get_sha256(path)
	return value.sha256_text()

static func apply(model: Node3D) -> int:
	var count := 0
	for candidate in model.find_children("*", "MeshInstance3D", true, false):
		var node := candidate as MeshInstance3D
		var boot := str(node.name).begins_with("Arjun_Boot_")
		var sole := str(node.name).begins_with("Boot outsole")
		var tail := str(node.name).begins_with("Sash hanging tail") or str(node.name) in ["Arjun_Detail_Faded madder-red sash","Arjun_Detail_Muted ochre sash thread"]
		if not (boot or sole or tail) or node.skin == null: continue
		var binds := {}
		for i in node.skin.get_bind_count(): binds[str(node.skin.get_bind_name(i))] = i
		var side := "r" if str(node.name).ends_with("-1") or tail else "l"
		var upper := "calf_"+side if boot or sole else "pelvis"
		var lower := "foot_"+side if boot or sole else "thigh_"+side
		var body := model.find_child("Arjun_MakeHuman_Body",true,false) as MeshInstance3D
		var toe_extension := 0.0
		if (boot or sole) and body != null:
			var frame := node.global_transform.affine_inverse()*body.global_transform
			var toe_front := -INF
			for surface in body.mesh.get_surface_count():
				for vertex: Vector3 in body.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					var point: Vector3 = frame*vertex
					if point.y < .14 and point.y >= -.02 and (point.x > 0.0) == (side == "l"):
						toe_front = maxf(toe_front,point.z)
			toe_extension = clampf(toe_front+.008-node.mesh.get_aabb().end.z,0.0,.06)
		if not binds.has(upper) or not binds.has(lower): continue
		var fitted := ArrayMesh.new()
		for surface in node.mesh.get_surface_count():
			var arrays := node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var influences: int = weights.size()/vertices.size()
			if influences < 2: continue
			for i in vertices.size():
				# The boot shaft and trouser cuff share the calf; the vamp flexes
				# with the foot. Pin the sash knot and drape its tail over the thigh.
				var upper_weight := smoothstep(.12,.21,vertices[i].y) if boot or sole else smoothstep(.78,1.055,vertices[i].y)
				if boot or sole:
					vertices[i].z += toe_extension*smoothstep(.025,.17,vertices[i].z)*(1.0-smoothstep(.11,.20,vertices[i].y))
				for slot in influences:
					bones[i*influences+slot] = 0
					weights[i*influences+slot] = 0.0
				bones[i*influences] = binds[upper]
				bones[i*influences+1] = binds[lower]
				weights[i*influences] = upper_weight
				weights[i*influences+1] = 1.0-upper_weight
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_WEIGHTS] = weights
			fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},node.mesh.surface_get_format(surface)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			fitted.surface_set_material(fitted.get_surface_count()-1,node.mesh.surface_get_material(surface))
		if fitted.get_surface_count() != node.mesh.get_surface_count(): continue
		if sole: _close_sole(fitted,int(binds["foot_"+side]))
		node.mesh = fitted
		count += 1
	return count

static func _close_sole(mesh: ArrayMesh, foot_bind: int) -> void:
	# Close the existing outsole's open underside with its own boundary shape.
	# Prone views expose that underside; an open tube reveals the retained foot.
	var bounds := mesh.get_aabb()
	var centre := bounds.get_center()
	var bins := {}
	for surface in mesh.get_surface_count():
		for point: Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			if point.y > bounds.position.y+.008: continue
			var angle := fposmod(atan2(point.z-centre.z,point.x-centre.x),TAU)
			var bin := floori(angle/TAU*64.0)
			var radius := Vector2(point.x-centre.x,point.z-centre.z).length_squared()
			if not bins.has(bin) or radius > float(bins[bin].radius): bins[bin] = {"point":point,"radius":radius}
	var keys: Array = bins.keys()
	keys.sort()
	if keys.size() < 12: return
	centre.y = bounds.position.y-.006
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(mesh.surface_get_material(0))
	for i in keys.size():
		var first: Vector3 = bins[keys[i]].point
		var second: Vector3 = bins[keys[(i+1)%keys.size()]].point
		first.y = centre.y
		second.y = centre.y
		for point: Vector3 in [centre,first,second]:
			surface.set_bones(PackedInt32Array([foot_bind,0,0,0]))
			surface.set_weights(PackedFloat32Array([1,0,0,0]))
			surface.set_normal(Vector3.DOWN)
			surface.set_uv(Vector2((point.x-bounds.position.x)/bounds.size.x,(point.z-bounds.position.z)/bounds.size.z))
			surface.add_vertex(point)
	surface.commit(mesh)

static func prepare_low_waist(model: Node3D, rebuild := false) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var cache_valid := false
	if not rebuild and FileAccess.file_exists(CACHE_DIR+"/manifest.json"):
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(CACHE_DIR+"/manifest.json"))
		cache_valid = manifest is Dictionary and manifest.get("fingerprint","") == fingerprint()
	var body := model.find_child("Arjun_MakeHuman_Body",true,false) as MeshInstance3D
	if body == null: return records
	for candidate in model.find_children("*","MeshInstance3D",true,false):
		var node := candidate as MeshInstance3D
		var footwear := str(node.name).begins_with("Arjun_Boot_") or str(node.name).begins_with("Boot outsole")
		if not footwear and not "DrapedTrousers" in str(node.name): continue
		if not rebuild:
			var path := CACHE_DIR+"/"+str(node.name).validate_filename()+".res"
			if cache_valid and ResourceLoader.exists(path): records.append({"node":node,"normal":node.mesh,"low":load(path)})
			continue
		var binds := {}
		for i in node.skin.get_bind_count(): binds[str(node.skin.get_bind_name(i))] = i
		var samples := {}
		var frame := node.global_transform.affine_inverse()*body.global_transform
		var normal_frame := frame.basis.inverse().transposed()
		for surface in body.mesh.get_surface_count():
			var data := body.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
			var skin_bones: PackedInt32Array = data[Mesh.ARRAY_BONES]
			var skin_weights: PackedFloat32Array = data[Mesh.ARRAY_WEIGHTS]
			var slots: int = skin_weights.size()/points.size()
			for i in points.size():
				var point: Vector3 = frame*points[i]
				if point.y < -.02 or point.y > 1.1: continue
				var weights := {}
				for slot in slots:
					var name := str(body.skin.get_bind_name(skin_bones[i*slots+slot]))
					if binds.has(name): weights[binds[name]] = float(weights.get(binds[name],0.0))+skin_weights[i*slots+slot]
				var cell := Vector3i(floori(point.x/.08),floori(point.y/.08),floori(point.z/.08))
				if not samples.has(cell): samples[cell] = []
				samples[cell].append({"point":point,"normal":(normal_frame*normals[i]).normalized(),"weights":weights})
		var fitted := ArrayMesh.new()
		for surface in node.mesh.get_surface_count():
			var arrays := node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var influences: int = weights.size()/vertices.size()
			for i in vertices.size():
				var point := vertices[i]
				var cell := Vector3i(floori(point.x/.08),floori(point.y/.08),floori(point.z/.08))
				var nearest: Array[Dictionary] = []
				for x in range(-1,2):
					for y in range(-1,2):
						for z in range(-1,2):
							for sample: Dictionary in samples.get(cell+Vector3i(x,y,z),[]):
								var distance: float = point.distance_squared_to(sample.point)
								if nearest.size() < 4 or distance < float(nearest[-1].distance):
									nearest.append({"sample":sample,"distance":distance})
									nearest.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.distance < b.distance)
									if nearest.size()>4: nearest.pop_back()
				if nearest.is_empty(): continue
				var combined := {}
				for record in nearest:
					var factor := 1.0/maxf(record.distance,.0001)
					for bind in record.sample.weights:
						combined[bind] = float(combined.get(bind,0.0))+record.sample.weights[bind]*factor
				var ranked: Array = combined.keys()
				ranked.sort_custom(func(a,b)->bool:return combined[a]>combined[b])
				var total := 0.0
				for slot in mini(influences,ranked.size()): total += combined[ranked[slot]]
				if total <= .0001: continue
				for slot in influences:
					bones[i*influences+slot] = 0
					weights[i*influences+slot] = 0.0
				for slot in mini(influences,ranked.size()):
					bones[i*influences+slot] = ranked[slot]
					weights[i*influences+slot] = combined[ranked[slot]]/total
				var closest: Dictionary = nearest[0].sample
				var clearance: float = (point-closest.point).dot(closest.normal)
				if not footwear and clearance < .009: vertices[i] += closest.normal*minf(.009-clearance,.04)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
			fitted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},node.mesh.surface_get_format(surface)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			fitted.surface_set_material(surface,node.mesh.surface_get_material(surface))
		records.append({"node":node,"normal":node.mesh,"low":fitted})
	return records

static func use_low_waist(records: Array[Dictionary], active: bool) -> void:
	for record in records:
		var target: Mesh = record.low if active else record.normal
		if record.node.mesh != target: record.node.mesh = target
