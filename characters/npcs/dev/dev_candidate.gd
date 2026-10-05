extends CharacterBody3D
## Dev's review actor. Story location and dialogue are assigned by story scenes.

@export var walking := false
@export var walk_speed := 0.9
var motion_tree: AnimationTree
var blend := 0.0
var turn_blend := 0.0
var desired_direction := Vector3.ZERO
@export var turn_speed := 2.5

func face_direction(direction: Vector3) -> void:
	direction.y = 0.0
	if direction.length_squared() > .001:
		desired_direction = direction.normalized()

func play_uniform_guard() -> void:
	if motion_tree:
		motion_tree.set("parameters/guard/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _ready() -> void:
	set_meta("character_id", "dev")
	set_meta("story_role", "Arjun's elder brother, sepoy")
	var player := $Visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(player != null)
	for name in ["Dev_idle_study", "Dev_walk_study", "Dev_turn_fit_study", "Dev_combat_fit_study"]:
		assert(player.has_animation(name))
		player.get_animation(name).loop_mode = Animation.LOOP_NONE if name == "Dev_combat_fit_study" else Animation.LOOP_LINEAR
	motion_tree = AnimationTree.new()
	add_child(motion_tree)
	motion_tree.anim_player = motion_tree.get_path_to(player)
	var graph := AnimationNodeBlendTree.new()
	var idle := AnimationNodeAnimation.new()
	idle.animation = "Dev_idle_study"
	var walk := AnimationNodeAnimation.new()
	walk.animation = "Dev_walk_study"
	graph.add_node("idle", idle)
	graph.add_node("walk", walk)
	graph.add_node("locomotion", AnimationNodeBlend2.new())
	graph.connect_node("locomotion", 0, "idle")
	graph.connect_node("locomotion", 1, "walk")
	var turn := AnimationNodeAnimation.new()
	turn.animation = "Dev_turn_fit_study"
	graph.add_node("turn", turn)
	graph.add_node("facing", AnimationNodeBlend2.new())
	graph.connect_node("facing", 0, "locomotion")
	graph.connect_node("facing", 1, "turn")
	var guard_clip := AnimationNodeAnimation.new()
	guard_clip.animation = "Dev_combat_fit_study"
	graph.add_node("guard_clip", guard_clip)
	var guard := AnimationNodeOneShot.new()
	guard.fadein_time = .15
	guard.fadeout_time = .2
	graph.add_node("guard", guard)
	graph.connect_node("guard", 0, "facing")
	graph.connect_node("guard", 1, "guard_clip")
	graph.connect_node("output", 0, "guard")
	motion_tree.tree_root = graph
	motion_tree.active = true

func _physics_process(delta: float) -> void:
	var turn_amount := 0.0
	if desired_direction.length_squared() > .001:
		var wanted := atan2(desired_direction.x, desired_direction.z)
		var difference := wrapf(wanted - rotation.y, -PI, PI)
		turn_amount = minf(1.0, absf(difference) / .35)
		rotation.y += clampf(difference, -turn_speed * delta, turn_speed * delta)
	var direction := global_basis.z.normalized()
	velocity.x = direction.x * walk_speed if walking else 0.0
	velocity.z = direction.z * walk_speed if walking else 0.0
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	var target := 1.0 if walking and Vector2(velocity.x, velocity.z).length() > .05 else 0.0
	blend = move_toward(blend, target, delta * 5.0)
	motion_tree.set("parameters/locomotion/blend_amount", blend)

	turn_blend = move_toward(turn_blend, turn_amount * (1.0 - blend), delta * 5.0)
	motion_tree.set("parameters/facing/blend_amount", turn_blend)
