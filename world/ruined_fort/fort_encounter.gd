extends Node3D
## Lazy four-person garrison. Each reused MPFB actor owns locomotion/combat trees.
const Actor = preload("res://characters/npcs/households/household_npc_actor.gd")
const Firearm = preload("res://world/ruined_fort/fort_guard_firearm.gd")
const Trace = preload("res://combat/ballistic_trace.gd")
const SITES := [Vector2(-8,22),Vector2(16,3),Vector2(-20,-16),Vector2(6,-35)]
var fort: Node3D
var player: CharacterBody3D
var guards: Array[Dictionary] = []
var saved_guards: Array = []
var completed := false
var activated := false
var sense_age := 0.0
var chest: Interactable
var announcement := false

func _ready() -> void:
	fort = get_parent().get_parent()
	add_to_group("institution_operations")
	chest = preload("res://world/ruined_fort/fort_supply_chest.gd").new()
	chest.name = "KeepSupplyChest"
	chest.encounter = self
	chest.position = Vector3(0,fort.height_at(0,-47)+.7,-47)
	add_child(chest)
	process_priority = 35

func find_player() -> CharacterBody3D:
	return get_tree().root.find_child("Player",true,false) as CharacterBody3D

func activate() -> void:
	if activated or completed: return
	activated = true
	for index in range(SITES.size()):
		var state: Dictionary = saved_guards[index] if index < saved_guards.size() and saved_guards[index] is Dictionary else {}
		if state.get("defeated",false): continue
		var actor := Actor.new()
		actor.name = "FortGuard"+str(index)
		actor.movement_enabled = false
		actor.foot_plant_enabled = true
		actor.set_meta("external_combat_motion",true)
		actor.set_meta("combat_faction","british")
		var site: Vector2 = SITES[index]
		actor.position = Vector3(site.x,fort.height_at(site.x,site.y),site.y)
		actor.add_child(preload("res://characters/npcs/british/private_man.glb").instantiate())
		add_child(actor)
		actor.rotation.y = 0
		actor.get_node("Vitality").health = clampf(float(state.get("health",75)),1,75)
		var weapon := Firearm.new()
		weapon.name = "FortEnfield"
		weapon.target = player
		weapon.cartridges = clampi(int(state.get("cartridges",4)),0,4)
		actor.add_child(weapon)
		guards.append({"id":index,"actor":actor,"weapon":weapon,"aware":false,"last_seen":actor.global_position,"lost":0.0,"path":PackedVector3Array(),"waypoint":0,"repath":0.0,"strike":0.0,"strike_hit":false})

func is_cleared() -> bool:
	if completed: return true
	if not activated: return false
	for guard in guards:
		var actor: Node3D = guard.actor
		if not actor.get_meta("dead",false) and not actor.get_meta("knocked_out",false): return false
	return true

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player): player = find_player()
	if player == null: return
	var distance: float = player.global_position.distance_to(fort.global_position)
	if not activated and distance < 105: activate()
	if not activated or distance > 150: return
	sense_age += delta
	var sense: bool = sense_age >= .25
	if sense: sense_age = 0
	for guard in guards:
		var actor: Node3D = guard.actor
		var weapon: Node3D = guard.weapon
		if actor.get_meta("dead",false) or actor.get_meta("knocked_out",false):
			weapon.hostile = false
			actor.travel_speed = 0
			continue
		if sense:
			var seen: bool = _visible(actor)
			guard.lost = 0.0 if seen else float(guard.lost)+.25
			if seen or actor.has_meta("last_attacker"):
				guard.aware = true
				if seen: guard.last_seen = player.global_position
			if guard.lost > 12: guard.aware = false
			weapon.hostile = guard.aware and seen
		guard.repath = maxf(0,float(guard.repath)-delta)
		var separation: float = actor.global_position.distance_to(player.global_position)
		if guard.aware and (not weapon.hostile or separation > 22 or weapon.cartridges == 0):
			if guard.repath <= 0:
				var goal: Vector3 = player.global_position if weapon.cartridges == 0 else _cover_goal(actor,guard.last_seen)
				guard.path = NavigationServer3D.map_get_path(fort.get_node("Navigation/FortWalkableRoutes").get_navigation_map(),actor.global_position,goal,true)
				guard.waypoint = 1
				guard.repath = 2.0
			_move(guard,delta)
		else:
			actor.travel_speed = 0
		weapon.moving = actor.travel_speed > .1
		if separation < 1.8 and guard.aware: _melee(guard,delta)
	if is_cleared() and not announcement:
		announcement = true
		player.inventory.message_requested.emit("Fort quiet · Recover supplies in the watchtower")

func _visible(actor: Node3D) -> bool:
	var stance := player.get_node_or_null("StealthStance")
	var origin := actor.global_position+Vector3.UP*1.4
	var target: Vector3 = stance.sight_target() if stance != null else player.global_position
	var limit: float = stance.visible_range(origin,36) if stance != null else 36
	if origin.distance_to(target) > limit: return false
	var excluded: Array[RID] = [actor.body_collider.get_rid()]
	var vitality := actor.get_node_or_null("Vitality")
	if vitality != null: excluded.append(vitality.hit_body.get_rid())
	var hit := Trace.sight(get_world_3d().direct_space_state,get_tree(),origin,target,excluded)
	return not hit.is_empty() and hit.collider == player

func _cover_goal(actor: Node3D, target: Vector3) -> Vector3:
	var best: Vector3 = target
	var score := INF
	for marker in get_tree().get_nodes_in_group("fort_cover_points"):
		if not fort.is_ancestor_of(marker): continue
		var point: Vector3 = marker.global_position
		var target_distance: float = point.distance_to(target)
		if target_distance < 7 or target_distance > 30: continue
		var candidate: float = actor.global_position.distance_to(point)+absf(target_distance-15)*.4
		if candidate >= score: continue
		var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*.8,target,1)
		query.exclude = [player.get_rid(),actor.body_collider.get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		best = point
		score = candidate
	return best

func _move(guard: Dictionary, delta: float) -> void:
	var actor: Node3D = guard.actor
	var path: PackedVector3Array = guard.path
	var index: int = guard.waypoint
	if index >= path.size(): actor.travel_speed = 0; return
	var offset: Vector3 = path[index]-actor.global_position
	offset.y = 0
	if offset.length() < .35: guard.waypoint = index+1; actor.travel_speed = 0; return
	var step := offset.normalized()*minf(delta*1.5,offset.length())
	var next: Vector3 = actor.global_position+step
	var query := PhysicsRayQueryParameters3D.create(next+Vector3.UP*1.0,next-Vector3.UP*1.0,1)
	query.exclude = [actor.body_collider.get_rid(),player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < .7 or absf(hit.position.y-actor.global_position.y) > .3: actor.travel_speed = 0; return
	next.y = hit.position.y+.015
	var body_shape: CollisionShape3D = actor.body_collider.get_node("BodyShape")
	var shape := PhysicsShapeQueryParameters3D.new()
	shape.shape = body_shape.shape
	shape.transform = body_shape.global_transform
	shape.transform.origin = next+Vector3.UP*(body_shape.position.y+.02)
	shape.exclude = [actor.body_collider.get_rid()]
	shape.collision_mask = 1
	shape.margin = .002
	if not get_world_3d().direct_space_state.intersect_shape(shape,1).is_empty(): actor.travel_speed = 0; return
	actor.global_position = next
	actor.global_rotation.y = rotate_toward(actor.global_rotation.y,atan2(offset.x,offset.z),delta*4)
	actor.travel_speed = step.length()/maxf(delta,.001)
	actor.body_collider.force_update_transform()

func _melee(guard: Dictionary, delta: float) -> void:
	guard.weapon.hostile = false
	guard.strike += delta
	if guard.strike < delta*1.5:
		guard.actor.combat_react("strike")
		guard.strike_hit = false
	if guard.strike > .42 and not guard.strike_hit:
		guard.strike_hit = true
		if _visible(guard.actor): player.take_damage(8)
	if guard.strike > 1.8: guard.strike = 0.0

func export_state() -> Dictionary:
	var states: Array = saved_guards.duplicate(true)
	while states.size() < SITES.size(): states.append({})
	for guard in guards:
		var actor: Node3D = guard.actor
		states[guard.id] = {"defeated":actor.get_meta("dead",false) or actor.get_meta("knocked_out",false),"health":actor.get_node("Vitality").health,"cartridges":guard.weapon.cartridges}
	return {"completed":completed,"guards":states}

func restore_state(state: Dictionary) -> void:
	completed = bool(state.get("completed",false))
	saved_guards = state.get("guards",[]) if state.get("guards",[]) is Array else []
	for guard in guards: guard.actor.queue_free()
	guards.clear()
	activated = false
	if completed: chest.restore_opened()
