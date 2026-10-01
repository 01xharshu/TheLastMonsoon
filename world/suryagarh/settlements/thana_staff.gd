extends Node3D
## Station-bound civilian police candidates for the fictional 1857 thana.
## Coordinates are in the DistrictPolice ground-floor frame.

const ROLES := [
	{"id":"daroga", "position":Vector3(9.0, 0, 6.8), "facing":-1.9},
	{"id":"mohurrir", "position":Vector3(9.5, 0, -5.7), "facing":2.5},
	{"id":"burkundaz", "position":Vector3(-5.5, 0, 7.5), "facing":.8},
]

func _ready() -> void:
	for record in ROLES:
		var role: String = record["id"]
		var scene := load("res://characters/npcs/thana/%s_motion.glb" % role) as PackedScene
		if scene == null:
			push_error("Missing thana staff: " + role)
			continue
		var actor := Node3D.new()
		actor.set_script(preload("res://characters/npcs/thana/thana_officer.gd"))
		actor.name = role.capitalize()
		actor.position = record["position"]
		actor.rotation.y = record["facing"]
		actor.set_meta("thana_role", role)
		actor.set_meta("station_bound", true)
		actor.set_meta("cultural_identity", "Sikh" if role=="burkundaz" else "unspecified")
		actor.set_meta("uniform_status", "1857_fictional_pattern_review_open")
		actor.set_meta("visual_status", "candidate_unapproved")
		actor.add_child(scene.instantiate())
		add_child(actor)
	var coordinator := preload("res://world/suryagarh/settlements/police_arrest.gd").new()
	coordinator.name = "ArrestCoordinator"
	add_child(coordinator)
