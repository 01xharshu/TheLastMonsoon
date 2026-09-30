extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
 var stage := Node3D.new()
 root.add_child(stage)
 var clock := Node.new()
 clock.name = "GameTimeSystem"
 clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
 stage.add_child(clock)
 var actor = load("res://player/player.tscn").instantiate()
 stage.add_child(actor)
 actor.set_physics_process(false)
 var visual = actor.get_node("VisualRoot/CharacterVisual")
 var clothes = visual.get_node("Clothing")
 assert(clothes.materials.size() >= 3, "Cotton surfaces missing")
 var cargo := Node3D.new()
 assert(clothes.mount_item(cargo, "back_upper"))
 assert(cargo.get_parent() == clothes.sockets.back_upper and clothes.shoulder.visible)
 assert(not clothes.mount_item(cargo, "missing_mount"))
 var initial: Vector3 = cargo.global_position
 actor.velocity.y = 5.0
 visual._process(.2)
 visual.skeleton.force_update_all_bone_transforms()
 for frame in 3: await process_frame
 assert(cargo.global_position.distance_to(initial) > .001, "Carrying mount failed to follow pose")
 actor.is_swimming = true
 clothes._process(1.0)
 assert(clothes.moisture > .6)
 actor.is_swimming = false
 clothes._process(1.0)
 assert(clothes.moisture > .5 and clothes.moisture < .65, "Cotton must dry gradually")
 assert(clothes.belt.mesh.get_aabb().size.x > .4)
 assert(clothes.tailored_meshes == 1)
 actor.velocity.z = -6.0
 for frame in 60: clothes._process(1.0/60.0)
 assert(clothes.fabric_sway.length() > .001 and clothes.fabric_sway.length() <= .018)
 actor.velocity = Vector3.ZERO
 for frame in 120: clothes._process(1.0/60.0)
 assert(clothes.fabric_sway.length() < .001, "Loose cloth did not settle")
 cargo.get_parent().remove_child(cargo)
 cargo.free()
 clothes._process(1.0/60.0)
 assert(not clothes.shoulder.visible and not clothes.shoulder_stitches.visible, "Empty carrying strap remained visible")
 print("ARJUN CLOTHING: PASS | cotton, wet/dry, mounts, animated support, belt/stitches, tailored hem, bounded cloth response/recovery")
 quit()
