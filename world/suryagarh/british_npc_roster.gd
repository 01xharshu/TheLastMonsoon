extends Node3D
## Places the eight British NPC study pairs in surveyed, walkable civic grounds.

const ACTOR = preload("res://characters/npcs/british/british_npc_actor.gd")
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const MODEL_DIR := "res://characters/npcs/british/"

func _ready() -> void:
	var compound_y: float = Layout.PLOTS["CompanyCompound"].grade + 0.08
	var residence_y: float = Layout.PLOTS["GovernmentHouse"].grade + 0.04
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
	for i in range(placements.size()):
		var record: Dictionary = placements[i]
		var rank: String = record["rank"]
		var origin: Vector3 = record["position"]
		_spawn(rank, "man", origin, float(i) * 1.1, 1.1 if rank != "official" else 0.5)
		_spawn(rank, "woman", origin + Vector3(2.7, 0, 0), 4.0 + float(i) * 1.1, 0.55)

func _spawn(rank: String, kind: String, origin: Vector3, offset: float, distance: float) -> void:
	var path := MODEL_DIR + rank + "_" + kind + ".glb"
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Missing British NPC model: " + path)
		return
	var actor := ACTOR.new() as Node3D
	actor.name = rank.capitalize() + ("Man" if kind == "man" else "Woman")
	actor.position = origin
	actor.set("cycle_offset", offset)
	actor.set("patrol_distance", distance)
	actor.set("patrol_axis", Vector3(0, 0, -1) if kind == "man" else Vector3(1, 0, 0))
	actor.set_meta("concept_rank_or_post", rank)
	actor.set_meta("visual_status", "candidate_unapproved")
	var model := scene.instantiate() as Node3D
	actor.add_child(model)
	add_child(actor)
