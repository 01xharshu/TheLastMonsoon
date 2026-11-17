extends SceneTree
## One input completes a supported low ledge traversal.
func _initialize() -> void: run.call_deferred()
func box(parent: Node3D, at: Vector3, size: Vector3) -> void:
 var body := StaticBody3D.new(); body.position = at
 var collision := CollisionShape3D.new(); var shape := BoxShape3D.new()
 shape.size = size; collision.shape = shape; body.add_child(collision); parent.add_child(body)
func run() -> void:
 create_timer(30.0).timeout.connect(func(): push_error("Low ledge test timed out"); quit(1))
 var scene := Node3D.new(); root.add_child(scene); current_scene = scene
 var clock := GameTimeSystem.new(); clock.name = "GameTimeSystem"; scene.add_child(clock)
 box(scene,Vector3(0,-.1,0),Vector3(10,.2,10))
 box(scene,Vector3(1.5,.45,0),Vector3(3,.9,4))
 var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
 scene.add_child(actor); actor.set_physics_process(false); actor.get_node("UI").hide()
 actor.global_position=Vector3(-.85,.94,0); actor.visual_root.global_rotation.y=PI/2
 await physics_frame
 var climb: Node = actor.get_node("ClimbComponent"); climb.set_physics_process(false)
 climb.catch_seconds = 1.0; climb.launch_y = actor.global_position.y-.2
 if not climb.try_start(): push_error("Supported ledge was not detected"); quit(1); return
 if not climb.window_committed: push_error("Ledge was not committed on the first press"); quit(1); return
 for frame in 240:
  climb._physics_process(1.0/60.0)
  if climb.waiting_for_move: push_error("Ledge paused for another press"); quit(1); return
  if not climb.active: break
 if climb.active or actor.global_position.x < .3: push_error("Ledge traversal did not complete"); quit(1); return
 print("LOW LEDGE SINGLE PRESS PASS")
 scene.queue_free()
 for frame in 3: await process_frame
 quit()
