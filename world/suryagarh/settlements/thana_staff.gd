extends Node3D
## Station-bound civilian police candidates for the fictional 1857 thana.
## Coordinates are in the DistrictPolice ground-floor frame.

const ROLES := [
	{"id":"daroga", "position":Vector3(9.0, 0, 6.8), "facing":-1.9},
	{"id":"mohurrir", "position":Vector3(9.5, 0, -5.7), "facing":2.5},
	{"id":"burkundaz", "position":Vector3(-5.5, 0, 7.5), "facing":-2.5},
]

func _ready() -> void:
	for record in ROLES:
		var role: String = record["id"]
		var scene := load("res://characters/npcs/thana/%s.glb" % role) as PackedScene
		if scene == null:
			push_error("Missing thana staff: " + role)
			continue
		var actor := StaticBody3D.new()
		actor.name = role.capitalize()
		actor.position = record["position"]
		actor.rotation.y = record["facing"]
		actor.collision_layer = 1
		actor.collision_mask = 0
		actor.set_meta("thana_role", role)
		actor.set_meta("station_bound", true)
		actor.set_meta("visual_status", "candidate_unapproved")
		add_child(actor)
		actor.add_child(scene.instantiate())
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = .32
		capsule.height = 1.65
		shape.shape = capsule
		shape.position.y = .83
		actor.add_child(shape)
