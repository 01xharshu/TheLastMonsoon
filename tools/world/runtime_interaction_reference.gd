extends "res://player/player_controller.gd"
## Pre-optimisation test-only behaviour reference.
func baseline_find_interactable() -> Interactable:
	var forward: Vector3 = -camera_pivot.global_basis.z if first_person else visual_root.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var view_camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
	var view_rect: Rect2 = get_viewport().get_visible_rect()
	var best: Interactable
	var best_score := -INF
	var origin := global_position + Vector3.UP * 1.35
	for node in get_tree().get_nodes_in_group("interactables"):
		if not is_instance_valid(node) or node.is_queued_for_deletion(): continue
		var candidate := node as Interactable
		if candidate == null or not candidate.interaction_available(): continue
		var screen_point := Vector2.ZERO
		if view_camera != null and candidate.is_in_group("weapon_pickups"):
			if view_camera.is_position_behind(candidate.interaction_anchor()): continue
			screen_point = view_camera.unproject_position(candidate.interaction_anchor())
			if not view_rect.has_point(screen_point): continue
		var target_point := candidate.interaction_anchor() if candidate.is_in_group("house_doors") else candidate.global_position
		var offset := target_point - global_position
		var distance := offset.length()
		if distance > candidate.interaction_max_distance: continue
		var flat := Vector3(offset.x, 0, offset.z)
		var alignment := forward.dot(flat.normalized()) if flat.length() > 0.1 else 1.0
		if alignment < 0.65: continue
		var query := PhysicsRayQueryParameters3D.create(origin, target_point)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider != candidate:
			query.from = global_position + Vector3.UP * 0.2
			hit = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider != candidate: continue
		var score := alignment * 2.0 - distance * 0.25
		if candidate.is_in_group("weapon_pickups") and view_camera != null:
			score -= screen_point.distance_to(view_rect.size * 0.5) / maxf(view_rect.size.y, 1.0) * 1.5
		if score > best_score:
			best = candidate
			best_score = score
	return best
