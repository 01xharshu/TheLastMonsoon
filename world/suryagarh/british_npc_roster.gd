extends Node3D
## Independent male and female preview residents; placement assigns no relationship.

const ACTOR = preload("res://characters/npcs/british/british_npc_actor.gd")
const PRIVATE_SKIRT_ACTOR = preload("res://characters/npcs/british/candidates/private_skirt_actor.gd")
const Startup = preload("res://systems/world_startup.gd")
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const MODEL_DIR := "res://characters/npcs/british/"

func _ready() -> void:
	var startup_task := Startup.begin("Roster")
	await Startup.checkpoint(self, "Preparing Suryagarh’s travellers…", true)
	var compound_y: float = Layout.PLOTS["CompanyCompound"].grade + 0.08
	var residence_y: float = Layout.PLOTS["GovernmentHouse"].grade + 0.04
	# GovernmentHouse.GardenWalk: centre +0.085, half-height 0.045.
	# Use its paved surface rather than the render-only parterre planting beds.
	var garden_walk_y: float = Layout.PLOTS["GovernmentHouse"].grade + 0.13
	var placements := [
		{"rank":"private", "position":Vector3(315, compound_y, 270)},
		{"rank":"corporal", "position":Vector3(329, compound_y, 273)},
		{"rank":"sergeant", "position":Vector3(345, compound_y, 274)},
		{"rank":"lieutenant", "position":Vector3(360, compound_y, 274)},
		{"rank":"captain", "position":Vector3(374, compound_y, 275)},
		{"rank":"major", "position":Vector3(314, compound_y, 298)},
		{"rank":"colonel", "position":Vector3(321, compound_y, 313)},
		{"rank":"official", "position":Vector3(-390, residence_y, -85)},
	]
	var female_positions := [
		Vector3(-442, garden_walk_y, -55), Vector3(-442, garden_walk_y, -45),
		Vector3(-338, garden_walk_y, -45), Vector3(-442, garden_walk_y, -75),
		Vector3(-338, garden_walk_y, -75), Vector3(-442, garden_walk_y, -95),
		Vector3(-338, garden_walk_y, -95), Vector3(-390, residence_y, -95),
	]
	for i in range(placements.size()):
		await Startup.checkpoint(self, "Preparing Suryagarh’s travellers…")
		var record: Dictionary = placements[i]
		var rank: String = record["rank"]
		var origin: Vector3 = record["position"]
		_spawn(rank, "man", origin, float(i) * 1.1, 0.9 if rank != "official" else 0.5)
		_spawn(rank, "woman", female_positions[i], 4.0 + float(i) * 1.1, 0.9)
	Startup.finish(startup_task)

func _spawn(rank: String, kind: String, origin: Vector3, offset: float, distance: float) -> void:
	var path := MODEL_DIR + rank + "_" + kind + ".glb"
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Missing British NPC model: " + path)
		return
	var actor := (PRIVATE_SKIRT_ACTOR.new() if rank in ["private", "corporal", "sergeant"] and kind == "woman" else ACTOR.new()) as Node3D
	actor.name = rank.capitalize() + ("Man" if kind == "man" else "Woman")
	actor.position = origin
	actor.set("cycle_offset", offset)
	actor.set("patrol_distance", distance)
	actor.set("patrol_axis", Vector3.RIGHT if kind == "woman" and rank == "official" else Vector3.FORWARD)
	actor.set("movement_profile", &"male" if kind == "man" else &"female")
	actor.set_meta("concept_rank_or_post", rank)
	if rank == "official" and kind == "man":
		actor.set_meta("story_role", "district commander")
		actor.set_meta("authority", "issues village rules from the occupied command fort")
	actor.set_meta("model_kind", kind)
	actor.set_meta("placement_plot", "GovernmentHouse" if kind == "woman" or rank == "official" else "CompanyCompound")
	actor.set_meta("visual_status", "candidate_unapproved")
	var model := scene.instantiate() as Node3D
	actor.add_child(model)
	add_child(actor)
