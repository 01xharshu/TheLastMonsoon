extends Node3D
var failures := 0
func _ready() -> void:
    _run.call_deferred()

func _box(label: String, position_at: Vector3, size: Vector3, color: Color, solid := true) -> Node3D:
    var body := StaticBody3D.new()
    body.name = label
    body.position = position_at
    add_child(body)
    var mesh := MeshInstance3D.new()
    var shape := BoxMesh.new()
    shape.size = size
    mesh.mesh = shape
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    mesh.material_override = material
    body.add_child(mesh)
    if solid:
        var collision := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = size
        collision.shape = box
        body.add_child(collision)
    return body

func _run() -> void:
    var clock := Node.new()
    clock.name = "GameTimeSystem"
    clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
    add_child(clock)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-35,-25,0)
    light.light_energy = 2.0
    add_child(light)
    _box("Floor",Vector3(0,-.1,0),Vector3(8,.2,8),Color(.4,.4,.3))
    _box("Sill",Vector3(0,.67,0),Vector3(.38,1.34,4),Color(.55,.35,.22))
    _box("Head",Vector3(0,3,0),Vector3(.38,1.02,4),Color(.55,.35,.22))
    for side in [-1,1]:
        _box("Pier",Vector3(0,1.915,side*1.55),Vector3(.38,1.15,.9),Color(.55,.35,.22))
    var portal := Node3D.new()
    portal.position = Vector3(0,1.34,0)
    add_child(portal)
    portal.add_to_group("climbable_windows")
    var actor: CharacterBody3D = preload("res://player/player.tscn").instantiate()
    add_child(actor)
    actor.set_physics_process(false)
    actor.get_node("UI").hide()
    actor.global_position = Vector3(-.9,.94,0)
    actor.visual_root.global_rotation.y = PI/2
    var climb: Node = actor.get_node("ClimbComponent")
    var visual: Node = actor.get_node("VisualRoot/CharacterVisual")
    var camera := Camera3D.new()
    camera.position = Vector3(-3.1,2.5,3.8)
    add_child(camera)
    camera.look_at(Vector3(0,1.4,0))
    camera.make_current()
    for i in 3: await get_tree().physics_frame
    if not climb.try_start() or not climb.window.active:
        push_error("WINDOW CLIMB: failed to start")
        get_tree().quit(1)
        return
    climb.set_physics_process(false)
    visual.set_process(false)
    var captures := [12,30,48,66,88]
    var folder := "res://docs/characters/arjun/window_climb"
    DirAccess.make_dir_recursive_absolute(folder)
    var movie := OS.get_cmdline_user_args().has("--movie")
    if movie: DirAccess.make_dir_recursive_absolute("/tmp/tlm_window_frames")
    for frame in 97:
        climb._physics_process(1.0/30.0)
        visual._process(1.0/30.0)
        for side in ["l","r"]:
            var crossing_foot: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("foot_"+side)).origin)
            if absf(crossing_foot.x)<.30 and crossing_foot.y<1.43:
                failures += 1
                print("FAIL boot sill clearance ",frame," ",crossing_foot)
        var head: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("head")).origin)
        if absf(head.x)<.25 and head.y>2.32:
            failures += 1
            print("FAIL head lintel clearance ",frame," ",head)
        if captures.has(frame):
            for side in ["l","r"]:
                var foot: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("foot_"+side)).origin)
                print("WINDOW FOOT ",frame," ",side," ",foot)
        if (captures.has(frame) or movie) and DisplayServer.get_name()!="headless":
            await get_tree().process_frame
            RenderingServer.force_draw(false)
            var pixels := get_viewport().get_texture().get_image()
            pixels.resize(960,540)
            if captures.has(frame):
                pixels.save_png(folder+"/phase_%02d.png"%frame)
                print("WINDOW CAPTURE ",frame)
            if movie: pixels.save_png("/tmp/tlm_window_frames/frame_%03d.png"%frame)
    if climb.active or actor.get_meta("climbing",false) or actor.collision_mask==0 or actor.global_position.x<.8:
        push_error("WINDOW CLIMB: completion failed")
        get_tree().quit(1)
        return
    actor.global_position = Vector3(.95,.94,0)
    actor.visual_root.global_rotation.y = -PI/2
    if not climb.window.try_start(actor):
        failures += 1
        print("FAIL reverse window entry")
    else:
        for i in 97: climb.window.advance(actor,1.0/30.0)
    actor.global_position = Vector3(-.9,.94,0)
    actor.visual_root.global_rotation.y = PI/2
    var obstacle := _box("BlockedLanding",Vector3(.95,.9,0),Vector3(.9,1.8,.9),Color(.3,.2,.1))
    await get_tree().physics_frame
    if climb.window.try_start(actor):
        failures += 1
        print("FAIL blocked landing accepted")
    obstacle.queue_free()
    await get_tree().physics_frame
    _box("ClosedShutter",Vector3(0,1.9,0),Vector3(.15,1.15,2.2),Color(.3,.2,.1))
    await get_tree().physics_frame
    if climb.window.try_start(actor):
        push_error("WINDOW CLIMB: crossed closed shutter")
        get_tree().quit(1)
        return
    print("WINDOW CLIMB: ","PASS" if failures==0 else "FAIL", " | both directions, boot/head clearance, restored collision, landing, blocked landing, closed shutter")
    get_tree().quit(1 if failures else 0)
