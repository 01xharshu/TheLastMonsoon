extends Node3D
var failures := 0
var max_palm_gap := 0.0
var min_palm_down := 1.0
var live_review := false
var review_dir := ""
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
    live_review = OS.get_cmdline_user_args().has("--review") and DisplayServer.get_name()!="headless"
    review_dir = OS.get_environment("TLM_WINDOW_REVIEW_DIR")
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
    actor.set_process(false)
    actor.get_node("UI").hide()
    actor.global_position = Vector3(-.9,.94,0)
    actor.visual_root.global_rotation.y = PI/2
    var climb: Node = actor.get_node("ClimbComponent")
    var visual: Node = actor.get_node("VisualRoot/CharacterVisual")
    var tunic := visual.model.find_child("Arjun_Kurta_SplitHem",true,false) as MeshInstance3D
    var original_tunic: Mesh = tunic.mesh
    var original_sash := {}
    for node in visual.model.find_children("*","MeshInstance3D",true,false):
        if str(node.name).begins_with("Sash hanging tail") or str(node.name) in ["Arjun_Detail_Faded madder-red sash","Arjun_Detail_Muted ochre sash thread"]: original_sash[node] = node.mesh
    var camera := Camera3D.new()
    camera.fov = 45.0
    camera.position = Vector3(-2.4,2.4,2.7)
    add_child(camera)
    camera.look_at(Vector3(0,1.4,0))
    camera.make_current()
    for i in 3: await get_tree().physics_frame
    if not _start_after_takeoff(actor,climb) or not climb.window.active:
        push_error("WINDOW CLIMB: failed to start")
        get_tree().quit(1)
        return
    climb.set_physics_process(false)
    visual.set_process(false)
    var equipment: Node = actor.get_node("VisualRoot/EquipmentVisuals")
    equipment.set_process(false)
    var bag: Node = equipment.get_node("WaterBagVisual")
    bag.set_process(false)
    if live_review: await get_tree().create_timer(.5).timeout
    for frame in 97:
        climb.request_move()
        climb._physics_process(1.0/30.0)
        visual._process(1.0/30.0)
        equipment._process(1.0/30.0)
        bag._process(1.0/30.0)
        for side in ["l","r"]:
            var crossing_foot: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("foot_"+side)).origin)
            if absf(crossing_foot.x)<.30 and crossing_foot.y<1.43:
                failures += 1
                print("FAIL boot sill clearance ",frame," ",crossing_foot)
        var head: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("head")).origin)
        if absf(head.x)<.25 and head.y>2.32:
            failures += 1
            print("FAIL head lintel clearance ",frame," ",head)
        _check_palms(visual,climb.window)
        if frame == 48: _check_garment(tunic)
        if frame == 80:
            camera.position = Vector3(2.4,2.0,2.7)
            camera.look_at(Vector3(.75,.8,0))
        if frame in [30,48,88]: await _review_frame("inside_out",frame)
        if live_review: await get_tree().create_timer(1.0/30.0).timeout
        if live_review and frame == 30: await get_tree().create_timer(1.0).timeout
    if climb.active or actor.get_meta("climbing",false) or actor.collision_mask==0 or actor.global_position.x<.8:
        push_error("WINDOW CLIMB: completion failed")
        get_tree().quit(1)
        return
    if tunic.mesh != original_tunic:
        failures += 1
        print("FAIL tunic was not restored after landing")
    for node in original_sash: assert(node.mesh == original_sash[node],"Landing retained gathered sash")
    actor.global_position = Vector3(.95,.94,0)
    actor.visual_root.global_rotation.y = -PI/2
    if not climb.window.try_start(actor):
        failures += 1
        print("FAIL reverse window entry")
    else:
        camera.position = Vector3(2.4,2.4,2.7)
        camera.look_at(Vector3(0,1.4,0))
        for i in 97:
            climb.window.advance(actor,1.0/30.0)
            visual._process(1.0/30.0)
            equipment._process(1.0/30.0)
            bag._process(1.0/30.0)
            _check_palms(visual,climb.window)
            if i == 48: _check_garment(tunic)
            if i == 80:
                camera.position = Vector3(-2.4,2.0,2.7)
                camera.look_at(Vector3(-.75,.8,0))
            if i in [30,48,88]: await _review_frame("outside_in",i)
            if live_review: await get_tree().create_timer(1.0/30.0).timeout
            if live_review and i == 30: await get_tree().create_timer(1.0).timeout
        if tunic.mesh != original_tunic:
            failures += 1
            print("FAIL reverse landing retained climbing tunic")
    for node in original_sash: assert(node.mesh == original_sash[node],"Reverse landing retained gathered sash")
    actor.global_position = Vector3(-.9,.94,0)
    actor.visual_root.global_rotation.y = PI/2
    var obstacle := _box("BlockedLanding",Vector3(.95,.9,0),Vector3(.9,1.8,.9),Color(.3,.2,.1))
    await get_tree().physics_frame
    if climb.window.try_start(actor):
        failures += 1
        print("FAIL blocked landing accepted")
    obstacle.queue_free()
    await get_tree().physics_frame
    var shutter := preload("res://objects/hinged_door.gd").new()
    shutter.width = 2.2
    shutter.height = 1.15
    shutter.opened = false
    shutter.position = Vector3(-1.1,1.34,0)
    shutter.build(StandardMaterial3D.new())
    shutter.rotation.y = PI*.5
    add_child(shutter)
    await get_tree().physics_frame
    if climb.window.try_start(actor):
        failures += 1
        print("FAIL closed hinged shutter accepted")
    shutter.restore_state(true)
    await get_tree().physics_frame
    if not climb.window.try_start(actor):
        failures += 1
        print("FAIL opened hinged shutter traversal")
    else:
        for i in 97: climb.window.advance(actor,1.0/30.0)
        if climb.window.active: failures += 1
    shutter.queue_free()
    await get_tree().physics_frame
    actor.global_position = Vector3(-.9,.94,0)
    actor.visual_root.global_rotation.y = PI/2
    _box("ClosedShutter",Vector3(0,1.9,0),Vector3(.15,1.15,2.2),Color(.3,.2,.1))
    await get_tree().physics_frame
    if climb.window.try_start(actor):
        push_error("WINDOW CLIMB: crossed closed shutter")
        get_tree().quit(1)
        return
    print("WINDOW PALM SUPPORT: max_gap_m=",max_palm_gap," min_down_dot=",min_palm_down)
    print("WINDOW CLIMB: ","PASS" if failures==0 else "FAIL", " | both directions, palm support/orientation, boot/head clearance, restored collision, landing, blocked landing, closed shutter")
    get_tree().quit(1 if failures else 0)

func _check_palms(visual: Node, window: RefCounted) -> void:
    var u: float = window.progress
    if u < .28 or u > .60: return
    for side in ["l","r"]:
        var hand: Transform3D = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_"+side))
        var palm: Vector3 = visual.skeleton.to_global(hand*visual.equipment.palm_offsets[side])
        var palm_in: Vector3 = visual.skeleton.global_basis*hand.basis*(visual.equipment.palm_axes[side] as Basis).z
        var target: Vector3 = window.sill+window.normal*(.08-.22*smoothstep(.30,.64,u))+window.tangent*(-.32 if side=="l" else .32)+Vector3.UP*.03
        var gap := palm.distance_to(target)
        var down := palm_in.dot(Vector3.DOWN)
        max_palm_gap = maxf(max_palm_gap,gap)
        min_palm_down = minf(min_palm_down,down)
        if gap > .012 or down < .95:
            failures += 1
            print("FAIL palm support phase=",u," side=",side," gap=",gap," down=",down)

func _review_frame(direction: String, frame: int) -> void:
    # The caller supplies an OS temporary directory and deletes it in finally.
    # Default verification writes no images or other test output.
    if review_dir.is_empty() or DisplayServer.get_name()=="headless": return
    await get_tree().process_frame
    RenderingServer.force_draw(false)
    await get_tree().process_frame
    RenderingServer.force_draw(false)
    get_viewport().get_texture().get_image().save_png(review_dir.path_join(direction+"_%02d.png"%frame))

func _start_after_takeoff(actor: CharacterBody3D, climb: Node) -> bool:
    climb.arm_jump()
    actor.global_position.y += .10
    return climb.try_start()

func _check_garment(tunic: MeshInstance3D) -> void:
    assert(tunic.mesh.get_blend_shape_count()==1 and tunic.mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_NORMALIZED,"Window fold mode would add absolute vertex coordinates")
    assert(tunic.get_blend_shape_value(0)>.9,"Deep crossing did not gather the hem")
    for surface in tunic.mesh.get_surface_count():
        var base: PackedVector3Array = tunic.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
        var folded: PackedVector3Array = tunic.mesh.surface_get_blend_shape_arrays(surface)[0][Mesh.ARRAY_VERTEX]
        assert(base.size()==folded.size(),"Gathered hem lost garment vertices")
        for vertex in base.size(): assert(base[vertex].distance_to(folded[vertex])<.1,"Gathered hem exceeded its physical fold allowance")
