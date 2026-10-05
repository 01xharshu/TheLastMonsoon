extends Node3D
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
    _box("Floor",Vector3(0,-.1,5),Vector3(12,.2,20),Color(.32,.35,.27))
    var actor: CharacterBody3D = preload("res://player/player.tscn").instantiate()
    add_child(actor)
    actor.set_physics_process(false)
    actor.set_process(false)
    actor.get_node("UI").hide()
    var climb: Node = actor.get_node("ClimbComponent")
    climb.set_physics_process(false)
    var visual: Node = actor.get_node("VisualRoot/CharacterVisual")
    visual.set_process(false)
    var camera := Camera3D.new()
    camera.fov = 45.0
    add_child(camera)
    camera.make_current()
    var failures := 0
    var folder := "res://docs/characters/arjun/object_climb_2026-10-01"
    DirAccess.make_dir_recursive_absolute(folder)
    var movie := OS.get_cmdline_user_args().has("--movie")
    for scenario in [{"name":"low_step","height":.75,"z":0.0},{"name":"high_mantle","height":1.65,"z":5.0}]:
        var height: float = scenario.height
        _box(scenario.name,Vector3(1,height*.5,scenario.z),Vector3(2,height,3),Color(.48,.32,.21))
        actor.global_position = Vector3(-.85,.94,scenario.z)
        actor.visual_root.global_rotation.y = PI/2
        for i in 3: await get_tree().physics_frame
        if not _start_after_takeoff(actor,climb) or climb.window.profile!=scenario.name:
            failures += 1
            print("FAIL object selection ",scenario.name)
            continue
        print("OBJECT PROFILE ",scenario.name," duration=",climb.window.duration)
        camera.global_position = Vector3(-3.1,2.4+height*.25,scenario.z+3.5)
        camera.look_at(Vector3(.2,height*.5+.55,scenario.z))
        var movie_folder: String = "/tmp/tlm_object_"+scenario.name
        if movie: DirAccess.make_dir_recursive_absolute(movie_folder)
        for frame in 61:
            climb.request_move()
            climb._physics_process(climb.window.duration/60.0)
            visual._process(1.0/30.0)
            if frame in [18,36]:
                for side in ["l","r"]:
                    var hand: Transform3D = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_"+side))
                    var palm: Vector3 = visual.skeleton.to_global(hand*visual.equipment.palm_offsets[side])
                    var target: Vector3 = climb.window.sill+climb.window.normal*(.08-.55*smoothstep(.42,.75,climb.window.progress))+climb.window.tangent*(-.32 if side=="l" else .32)+Vector3.UP*.03
                    if climb.window.surface != null:
                        var support: Dictionary = climb.window.surface.contact(climb.window.sill-climb.window.normal*(.22+.48*smoothstep(.42,.75,climb.window.progress))+climb.window.tangent*(-.32 if side=="l" else .32))
                        if not support.is_empty(): target = support.position+support.normal*.03
                    var gap: float = palm.distance_to(target)
                    print("OBJECT PALM ",scenario.name," ",frame," ",side," gap=",gap)
                    if gap>.04:
                        failures += 1
                        print("FAIL supporting palm gap")
            if (frame in [18,36,50] or movie) and DisplayServer.get_name()!="headless":
                await get_tree().process_frame
                RenderingServer.force_draw(false)
                var pixels := get_viewport().get_texture().get_image()
                pixels.resize(960,540)
                if frame in [18,36,50]: pixels.save_png(folder+"/"+scenario.name+"_%02d.png"%frame)
                if movie: pixels.save_png(movie_folder+"/frame_%03d.png"%frame)
        if climb.active or actor.collision_mask==0 or absf(actor.global_position.y-height-.94)>.01:
            failures += 1
            print("FAIL object landing ",scenario.name)
    var rotated := _box("RotatedLedge",Vector3(5,.75,10),Vector3(2,1.5,3),Color(.48,.32,.21))
    rotated.rotation.y = PI/2
    actor.global_position = Vector3(5,.94,8.15)
    actor.visual_root.global_rotation.y = 0.0
    for i in 3: await get_tree().physics_frame
    if not _start_after_takeoff(actor,climb):
        failures += 1
        print("FAIL rotated ledge selection")
    else:
        for i in 61:
            climb.request_move()
            climb._physics_process(climb.window.duration/60.0)
        if actor.global_position.z<9.5:
            failures += 1
            print("FAIL rotated ledge landing")
    _box("NarrowLip",Vector3(.19,.75,10),Vector3(.38,1.5,3),Color(.48,.32,.21))
    actor.global_position = Vector3(-.85,.94,10)
    actor.visual_root.global_rotation.y = PI/2
    for i in 3: await get_tree().physics_frame
    if _start_after_takeoff(actor,climb):
        failures += 1
        print("FAIL unsupported narrow lip accepted")
    print("OBJECT CLIMB: ","PASS" if failures==0 else "FAIL"," | low step, high mantle, supporting palms, rotated ledge, supported landing, narrow lip rejection")
    get_tree().quit(0 if failures==0 else 1)

func _start_after_takeoff(actor: CharacterBody3D, climb: Node) -> bool:
    climb.arm_jump()
    actor.global_position.y += .10
    return climb.try_start()
