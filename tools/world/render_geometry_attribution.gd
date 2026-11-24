extends RefCounted
## Diagnostic only: paired render exclusions in one frozen populated world.
## Visibility and shadow state are restored; this never changes production budgets.
const Snapshot = preload("res://tools/world/performance_snapshot.gd")

static func category(node: GeometryInstance3D) -> String:
	var path := str(node.get_path())
	if node is MeshInstance3D and node.skin!=null: return "skinned"
	if str(node.name).begins_with("BroadleafTrees"): return "broadleaf"
	if str(node.name).begins_with("Grass"): return "grass"
	if "/WorldForestPatch/" in path: return "forest_patch"
	if "/Landscape/TerrainTiles/" in path or str(node.name)=="DistantTerrain_NoCollision": return "terrain"
	if "/Settlement/" in path or "/WealthyHouseholds/" in path: return "settlement_geometry"
	return "other"

static func quantile(values: Array[float],fraction: float) -> float:
	values.sort()
	return values[int((values.size()-1)*fraction)]

static func viewport_workload(rid: RID) -> Vector4i:
	var visible := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
	var shadow := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW
	var draws := RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
	var primitives := RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME
	return Vector4i(
		RenderingServer.viewport_get_render_info(rid, visible, draws),
		RenderingServer.viewport_get_render_info(rid, visible, primitives),
		RenderingServer.viewport_get_render_info(rid, shadow, draws),
		RenderingServer.viewport_get_render_info(rid, shadow, primitives)
	)

static func run(tree: SceneTree,world: Node3D,actor: Node3D,camera: Camera3D) -> bool:
	var area := "cantonment"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--area="): area=argument.trim_prefix("--area=")
	var views := {"village":[Vector3(-310,9,245),Vector3(-310,9,230)],"civil_lines":[Vector3(665,12,275),Vector3(640,12,235)],"cantonment":[Vector3(500,11,510),Vector3(500,10,465)]}
	# Reuse the authored forest review location and an eye-height player view.
	var forest_point: Vector2=world.REVIEW_POINTS[5]
	views["forest"]=[Vector3(forest_point.x,0,forest_point.y),Vector3(forest_point.x+20,0,forest_point.y)]
	if area=="broadleaf_close":
		var nearest := Vector3.ZERO
		var distance := INF
		for batch in world.get_node("Landscape/NatureTiles").find_children("BroadleafTrees*","MultiMeshInstance3D",true,false):
			for index in batch.multimesh.instance_count:
				var transform: Transform3D=batch.multimesh.get_instance_transform(index)
				if is_zero_approx(transform.basis.determinant()): continue
				var point: Vector3=batch.global_transform*transform.origin
				var squared := Vector2(point.x+500,point.z+300).length_squared()
				if squared<distance: distance=squared;nearest=point
		assert(distance<INF,"Close review requires an established broadleaf tree")
		views[area]=[nearest+Vector3(9,0,14),nearest+Vector3.UP*4.0]
		print("GEOMETRY CLOSE TREE ",nearest)
	assert(views.has(area),"Geometry attribution requires an established fixed-view area")
	camera.global_position=views[area][0]
	# Fixed world Y and placing the free camera inside the player gave an
	# obstructed diagnostic. Ground the eye and keep the player behind it.
	camera.global_position.y=world.layout.height(camera.global_position.x,camera.global_position.z)+(3.0 if area=="broadleaf_close" else 1.7)
	var target: Vector3=views[area][1]
	if area!="broadleaf_close": target.y=camera.global_position.y
	else:
		# The nearest baked tree can now be behind a later settlement building.
		# Choose a clear canopy ray rather than accepting a wall-filled review.
		var center: Vector3=views[area][1]-Vector3.UP*4.0
		var clear := false
		for height in [4.0,8.0]:
			target=center+Vector3.UP*height
			for angle_index in 8:
				var angle: float=angle_index*TAU/8.0
				var eye := center+Vector3(sin(angle)*17.0,0,cos(angle)*17.0)
				eye.y=world.layout.height(eye.x,eye.z)+height
				var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,target,1))
				if hit.is_empty() or hit.position.distance_to(target)<2.0:
					camera.global_position=eye;clear=true;break
			if clear: break
		assert(clear,"No unobstructed native close-tree view was found")
	camera.look_at(target)
	actor.global_position=camera.global_position+camera.global_basis.z*4.0
	actor.global_position.y=world.layout.height(actor.global_position.x,actor.global_position.z)+1.1
	for frame in 90: await tree.process_frame
	var previously_paused := tree.paused
	var force_sampling := "--force-render-sampling" in OS.get_cmdline_user_args()
	var original_render_loop := RenderingServer.render_loop_enabled
	var submitted := [0]
	var submission_counter := func(): submitted[0] += 1
	if force_sampling:
		RenderingServer.render_loop_enabled = false
		RenderingServer.frame_post_draw.connect(submission_counter)
	tree.paused=true
	var groups := {}
	var original: Array = []
	var inventory := {}
	for node in world.find_children("*","GeometryInstance3D",true,false):
		var group := category(node)
		if not groups.has(group): groups[group]=[];inventory[group]={"nodes":0,"source_vertices":0,"mesh_records":0,"shadow_nodes":0}
		groups[group].append(node)
		original.append([node,node.visible,node.cast_shadow,node.lod_bias])
		var row: Dictionary=inventory[group]
		row.nodes+=1
		if node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: row.shadow_nodes+=1
		var mesh: Mesh
		var instances := 1
		if node is MeshInstance3D: mesh=node.mesh
		elif node is MultiMeshInstance3D and node.multimesh!=null:
			mesh=node.multimesh.mesh
			instances=node.multimesh.instance_count if node.multimesh.visible_instance_count<0 else node.multimesh.visible_instance_count
		if mesh!=null:
			row.mesh_records+=instances
			if mesh is ArrayMesh:
				for surface in mesh.get_surface_count(): row.source_vertices+=mesh.surface_get_array_len(surface)*instances
			elif mesh is PrimitiveMesh:
				row.source_vertices+=mesh.get_mesh_arrays()[Mesh.ARRAY_VERTEX].size()*instances
	print("GEOMETRY INVENTORY ",JSON.stringify(inventory)," | source metadata upper bounds, before LOD/culling; not GPU vertex invocations")
	var viewport: Viewport=tree.root
	var rid := viewport.get_viewport_rid()
	print("GEOMETRY CONTEXT ",JSON.stringify({"area":area,"viewport":str(viewport.size),"scale":viewport.scaling_3d_scale,"lod_threshold":viewport.mesh_lod_threshold,"game_minutes":world.get_node("GameTimeSystem").total_game_minutes,"population_frozen":true,"snapshot":Snapshot.capture()}))
	var modes: Array = ["baseline","broadleaf","grass","terrain","skinned","settlement_geometry","forest_patch","broadleaf_shadows","restored"]
	if "--tree-lod" in OS.get_cmdline_user_args(): modes=["baseline","broadleaf_far_lod","restored"]
	var compacted: Array=[]
	if "--tree-compact" in OS.get_cmdline_user_args():
		modes=["baseline","broadleaf_compact","restored"]
		var records := 0
		var removed := 0
		for node in groups.get("broadleaf",[]):
			var source: MultiMesh=node.multimesh
			var candidate := preload("res://world/suryagarh/broadleaf_render_records.gd").compact(source)
			records+=source.instance_count
			removed+=source.instance_count-candidate.instance_count
			compacted.append([node,source,candidate])
		print("GEOMETRY COMPACTION ",JSON.stringify({"records":records,"removed_collapsed":removed}))
	var moving_lod := "--moving-lod" in OS.get_cmdline_user_args()
	if moving_lod: modes = ["baseline", "baseline_repeat", "broadleaf_far_lod", "restored"]
	var close_eye := camera.global_position
	var far_eye := close_eye + camera.global_basis.z * 70.0
	var lod_batches: Array = []
	if moving_lod:
		for node: MultiMeshInstance3D in groups.get("broadleaf", []):
			if node.lod_bias > 1.0:
				lod_batches.append([node, node.global_transform * node.get_aabb(), node.lod_bias])
	var baseline_route: Array[Vector4i] = []
	var repeat_matches := true
	var baseline_workload := Vector4i.ZERO
	var restored_workload_matches := true
	for mode in modes:
		if moving_lod: camera.global_position = far_eye
		for saved in compacted: saved[0].multimesh=saved[2] if mode=="broadleaf_compact" else saved[1]
		for saved in original:
			saved[0].visible=saved[1]
			saved[0].cast_shadow=saved[2]
			saved[0].lod_bias=saved[3]
		if mode == "broadleaf_far_lod" and not moving_lod:
			var changed := 0
			for node: MultiMeshInstance3D in groups.get("broadleaf", []):
				var bounds: AABB = node.global_transform * node.get_aabb()
				var nearest := camera.global_position.clamp(bounds.position, bounds.end)
				if nearest.distance_squared_to(camera.global_position) > 45.0 * 45.0:
					node.lod_bias = minf(node.lod_bias, 1.0)
					changed += 1
			print("BROADLEAF FAR LOD | batches beyond 45 m: ", changed)
		elif mode=="broadleaf_shadows":
			for node in groups.get("broadleaf",[]): node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif groups.has(mode):
			for node in groups[mode]: node.hide()
		for frame in 30:
			await tree.process_frame
			if force_sampling: RenderingServer.force_draw()
		if mode=="baseline" or "--tree-lod" in OS.get_cmdline_user_args() or "--tree-compact" in OS.get_cmdline_user_args():
			for argument in OS.get_cmdline_user_args():
				if argument.begins_with("--review-dir="):
					if force_sampling: RenderingServer.force_draw()
					else: await RenderingServer.frame_post_draw
					var directory := argument.trim_prefix("--review-dir=")
					assert(directory.is_absolute_path() and directory.get_file().begins_with("tlm-performance-"))
					var pixels := viewport.get_texture().get_image()
					pixels.resize(1280,720,Image.INTERPOLATE_LANCZOS)
					pixels.save_png(directory.path_join("geometry_"+mode+".png"))
		var workload_counts := {}
		var over_budget := 0
		var wall: Array[float]=[]
		var gpu: Array[float]=[]
		var cpu: Array[float]=[]
		var draws: Array[float]=[]
		var primitives: Array[float]=[]
		var draws_before: int = submitted[0] if force_sampling else Engine.get_frames_drawn()
		var window_started := Time.get_ticks_usec()
		var route_matches := 0
		var reduced_min := lod_batches.size()
		var reduced_max := 0
		var warmup_samples := 120 if moving_lod else 0
		for sample in range(-warmup_samples, 120):
			var frame := posmod(sample, 120)
			if sample == 0 and moving_lod:
				viewport.get_texture().get_image()
				draws_before = submitted[0] if force_sampling else Engine.get_frames_drawn()
				window_started = Time.get_ticks_usec()
			var start := Time.get_ticks_usec()
			await tree.process_frame
			if moving_lod:
				# Replay an identical approach and retreat at sample-indexed positions.
				var progress := 1.0 - absf(2.0 * float(frame) / 119.0 - 1.0)
				var eye := far_eye.lerp(close_eye, progress)
				camera.global_position = eye
				var reduced := 0
				if mode == "broadleaf_far_lod":
					for batch in lod_batches:
						var bounds: AABB = batch[1]
						var far := eye.distance_squared_to(eye.clamp(bounds.position, bounds.end)) > 2025.0
						var bias: float = 1.0 if far else batch[2]
						if batch[0].lod_bias != bias: batch[0].lod_bias = bias
						if far: reduced += 1
				if sample >= 0:
					reduced_min = mini(reduced_min, reduced)
					reduced_max = maxi(reduced_max, reduced)
			if force_sampling: RenderingServer.force_draw()
			if sample < 0: continue
			var elapsed_ms := (Time.get_ticks_usec()-start)/1000.0
			wall.append(elapsed_ms)
			if elapsed_ms > 33.333: over_budget += 1
			var workload := viewport_workload(rid)
			if moving_lod:
				if mode == "baseline": baseline_route.append(workload)
				if mode in ["baseline_repeat", "restored"]:
					var expected := baseline_route[frame]
					if workload == expected:
						route_matches += 1
					else:
						print("GEOMETRY ROUTE DELTA phase=", mode, " sample=", frame,
							" (visible draws/primitives, shadow draws/primitives)=", workload - expected)
			workload_counts[workload] = workload_counts.get(workload, 0) + 1
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		if force_sampling:
			# Drain submitted GPU work once, outside per-frame samples. Include the
			# readback in window mean so queued bursts cannot fake high throughput.
			var last_frame := viewport.get_texture().get_image()
			assert(not last_frame.is_empty(), "Forced rendering produced no image")
		var render_window_mean := float(Time.get_ticks_usec()-window_started)/1000.0/wall.size()
		if (submitted[0] if force_sampling else Engine.get_frames_drawn()) - draws_before < wall.size() / 2:
			push_error("Geometry sampling lost rendered frames during %s. Keep the Godot window visible and retry." % mode)
			for saved in original:
				saved[0].visible = saved[1]
				saved[0].cast_shadow = saved[2]
				saved[0].lod_bias = saved[3]
			for saved in compacted: saved[0].multimesh = saved[1]
			if force_sampling: RenderingServer.frame_post_draw.disconnect(submission_counter)
			RenderingServer.render_loop_enabled = original_render_loop
			tree.paused = previously_paused
			return false
		var dominant := Vector4i.ZERO
		var dominant_count := 0
		for workload in workload_counts:
			if workload_counts[workload] > dominant_count:
				dominant = workload
				dominant_count = workload_counts[workload]
		if mode == "baseline": baseline_workload = dominant
		if mode == "restored":
			restored_workload_matches = dominant == baseline_workload and baseline_workload.x > 0
		if moving_lod:
			if mode == "baseline_repeat": repeat_matches = route_matches == wall.size()
			if mode == "restored": restored_workload_matches = route_matches == wall.size() and repeat_matches
			print("GEOMETRY ROUTE ", mode, " matched_restored_positions=", route_matches,
				" reduced_batches_min=", reduced_min, " reduced_batches_max=", reduced_max)
		print("GEOMETRY WORKLOAD ", JSON.stringify({
			"phase": mode, "visible_draws": dominant.x, "visible_primitives": dominant.y,
			"shadow_draws": dominant.z, "shadow_primitives": dominant.w,
			"matching_samples": dominant_count, "distinct_workloads": workload_counts.size(),
			"frames_over_33_333_ms": over_budget,
			"restored_workload_matches": restored_workload_matches if mode == "restored" else null
		}))
		var gpu_median := quantile(gpu,.5)
		print("GEOMETRY ATTRIBUTION ",JSON.stringify({"excluded":mode,"samples":wall.size(),"sampling":"forced paused render throughput" if force_sampling else "automatic paused frames","render_submissions":(submitted[0] if force_sampling else Engine.get_frames_drawn())-draws_before,"render_window_mean_ms":render_window_mean,"wall_p50_ms":quantile(wall,.5),"wall_p95_ms":quantile(wall,.95),"wall_p99_ms":quantile(wall,.99),"render_cpu_ms":quantile(cpu,.5),"render_gpu_ms":gpu_median if gpu_median>0 else null,"draws":quantile(draws,.5),"primitives":quantile(primitives,.5),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}))
	for saved in original:
		assert(saved[0].visible==saved[1] and saved[0].cast_shadow==saved[2] and saved[0].lod_bias==saved[3],"Diagnostic failed to restore renderer state")
	if moving_lod: camera.global_position = close_eye
	if force_sampling: RenderingServer.frame_post_draw.disconnect(submission_counter)
	RenderingServer.render_loop_enabled = original_render_loop
	tree.paused=previously_paused
	return restored_workload_matches if "--tree-lod" in OS.get_cmdline_user_args() else true
