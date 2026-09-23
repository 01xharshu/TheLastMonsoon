extends SceneTree
## Stages the real horse/rider just outside the stable, then captures native-renderer action frames.
func _initialize() -> void:
    _capture.call_deferred()

func _capture() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("HORSE CAPTURE BLOCKED: rendering backend required")
        quit(1)
        return
    var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    var actor: CharacterBody3D = world.get_node("Player")
    actor.set_physics_process(false)
    actor.get_node("UI").hide()
    world.get_node("LandscapeUI").hide()
    for i in 15: await process_frame
    var horse: CharacterBody3D = world.get_node("VillageHorse")
    actor.global_position = horse.global_position + Vector3(0,1,2)
    if not horse.board(actor):
        push_error("HORSE CAPTURE BLOCKED: could not mount")
        quit(1)
        return
    horse.global_position = Vector3(-258,world.layout.height(-258,203)+.15,203)
    var camera := Camera3D.new()
    world.add_child(camera)
    camera.fov = 52
    camera.make_current()
    for i in 90: await physics_frame
    await _shot(camera,horse,"19_horse_rider_side")
    actor.get_node("UI").show()
    await _shot(camera,horse,"23_horse_stamina")
    actor.get_node("UI").hide()
    Input.action_press("move_forward")
    for i in 40: await physics_frame
    await _shot(camera,horse,"21_horse_walk")
    Input.action_press("sprint")
    for i in 85: await physics_frame
    await _shot(camera,horse,"24_horse_gallop")
    Input.action_release("sprint")
    Input.action_press("jump")
    for i in 8: await physics_frame
    Input.action_release("jump")
    Input.action_release("move_forward")
    await _shot(camera,horse,"22_horse_jump")
    quit()

func _shot(camera: Camera3D, horse: CharacterBody3D, name: String) -> void:
    camera.global_position = horse.global_position + horse.global_basis * Vector3(-6,2.6,2.5)
    camera.look_at(horse.global_position + Vector3.UP*1.5)
    for i in 8: await process_frame
    await RenderingServer.frame_post_draw
    var path := "res://docs/world/captures/" + name + ".png"
    var err := root.get_texture().get_image().save_png(path)
    assert(err == OK, path)
    print("HORSE CAPTURE ",path)
