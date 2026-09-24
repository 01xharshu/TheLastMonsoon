extends Node
## Applies a brief rest-relative low reach after ordinary locomotion poses.
@onready var actor: CharacterBody3D = get_parent()
@onready var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
var amount := 0.0
var pose_kind := "none"
var release_linger := 0.0

func _ready() -> void:
	process_priority = 10

func _process(delta: float) -> void:
	if visual.skeleton == null: return
	if actor.get_meta("climbing",false) or actor.has_meta("mounted_vehicle") or actor.get_meta("river_action","") != "" or actor.get_meta("stealth_stance","") != "": return
	var active: bool = actor.get_meta("interaction_reach",false)
	if active:
		pose_kind = str(actor.get_meta("interaction_pose_kind","low_reach"))
		release_linger = .3
	else:
		release_linger = maxf(0.0,release_linger-delta)
	amount = move_toward(amount,1.0 if active or release_linger > 0.0 else 0.0,delta*3.5)
	if amount <= .001: return
	var weight := clampf(amount*.72,0.0,.72)
	var deep := pose_kind == "kneel"
	var drop := .40 if deep else .25
	visual.model.position.y = lerpf(visual.model.position.y,-.9-drop,amount)
	visual.model.rotation.x = lerpf(visual.model.rotation.x,.11 if deep else .07,amount)
	visual.pose("pelvis",Vector3(.08,0,0),weight)
	visual.pose("spine_01",Vector3(.46 if deep else .34,0,0),weight)
	visual.pose("spine_02",Vector3(.22 if deep else .13,0,0),weight)
	visual.pose("head",Vector3(-.18,0,0),weight)
	visual.pose("thigh_l",Vector3(1.08 if deep else .88,0,-.12),weight)
	visual.pose("calf_l",Vector3(-1.58 if deep else -1.15,0,0),weight)
	visual.pose("thigh_r",Vector3(.76 if deep else .88,0,.10),weight)
	visual.pose("calf_r",Vector3(-1.15,0,0),weight)
	visual.pose("foot_l",Vector3(.32,0,0),weight)
	visual.pose("foot_r",Vector3(.20,0,0),weight)
	visual.pose("upperarm_r",Vector3(-1.12,0,.22),weight)
	visual.pose("lowerarm_r",Vector3(-.65,0,0),weight)
	visual.pose("upperarm_l",Vector3(-.73,0,-.20),weight)
	visual.pose("lowerarm_l",Vector3(-.78,0,0),weight)
