extends CharacterBody3D
## Dev's review actor. Story location and dialogue are assigned by story scenes.

@export var walking := false
@export var walk_speed := 0.9
var motion_tree: AnimationTree
var blend := 0.0

func _ready() -> void:
	set_meta("character_id", "dev")
	set_meta("story_role", "Arjun's elder brother, sepoy")
	var player := $Visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(player != null)
	for name in ["Dev_idle_study", "Dev_walk_study"]:
		assert(player.has_animation(name))
		player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
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
	graph.connect_node("output", 0, "locomotion")
	motion_tree.tree_root = graph
	motion_tree.active = true

func _physics_process(delta: float) -> void:
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
