extends Node
## Four shared vehicle wake emitters; no per-blade processing or physics.
var slots: Array[Dictionary] = []
var refresh := 0.0
func _ready() -> void:
	for i in 4: slots.append({"node":null,"position":Vector3.ZERO,"strength":0.0})
func _process(delta: float) -> void:
	refresh -= delta
	if refresh <= 0.0:
		refresh = .2
		var vehicles: Array[Node3D] = []
		for group in ["cart_parking_vehicles","live_travel_carts","bullock_carts"]:
			for node in get_tree().get_nodes_in_group(group):
				if node is Node3D and not vehicles.has(node): vehicles.append(node)
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			vehicles.sort_custom(func(a,b): return a.global_position.distance_squared_to(camera.global_position)<b.global_position.distance_squared_to(camera.global_position))
		vehicles.resize(mini(4,vehicles.size()))
		for slot in slots:
			if not is_instance_valid(slot.node) or not vehicles.has(slot.node): slot.node = null
		for vehicle in vehicles:
			var assigned := false
			for slot in slots:
				if slot.node == vehicle: assigned = true
			if assigned: continue
			for slot in slots:
				if slot.node == null:
					slot.node = vehicle
					slot.position = vehicle.global_position
					slot.strength = 0.0
					break
	for i in slots.size():
		var slot: Dictionary = slots[i]
		var target := 0.0
		if is_instance_valid(slot.node):
			var position: Vector3 = slot.node.global_position
			var travel: float = position.distance_to(slot.position)
			# Ignore teleports; parked carts produce no permanent bending.
			if travel < 2.0: target = clampf(travel/maxf(delta,.001)/6.0,0.0,1.0)
			slot.position = position
		slot.strength = lerpf(slot.strength,target,1.0-exp(-delta*(7.0 if target>slot.strength else 2.3)))
		var p: Vector3 = slot.position
		RenderingServer.global_shader_parameter_set("grass_vehicle_%d" % i,Vector4(p.x,p.y,p.z,slot.strength))
func _exit_tree() -> void:
	for i in 4: RenderingServer.global_shader_parameter_set("grass_vehicle_%d" % i,Vector4.ZERO)
