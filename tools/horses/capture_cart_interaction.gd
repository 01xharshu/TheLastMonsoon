extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
 if DisplayServer.get_name() == "headless": quit(1); return
 root.size = Vector2i(1280,720)
 var stage := Node3D.new()
 root.add_child(stage)
 var ground := MeshInstance3D.new()
 var plane := PlaneMesh.new()
 plane.size = Vector2(20,20)
 ground.mesh = plane
 stage.add_child(ground)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-45,-30,0)
 sun.light_energy = 1.7
 stage.add_child(sun)
 var actor: CharacterBody3D = load("res://tools/world/interaction_test_actor.gd").new()
 stage.add_child(actor)
 actor.position = Vector3(2,0,2.2)
 var ui := CanvasLayer.new()
 ui.name = "UI"
 actor.add_child(ui)
 var hud := Control.new()
 hud.name = "HUDRoot"
 ui.add_child(hud)
 hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var overlay: Control = load("res://interaction/interaction_overlay.gd").new()
 overlay.name = "InteractionOverlay"
 hud.add_child(overlay)
 var camera := Camera3D.new()
 camera.position = Vector3(4,2.7,4.8)
 stage.add_child(camera)
 camera.look_at(Vector3(0,1.6,2.2))
 camera.make_current()
 var cart: Node3D = load("res://vehicles/family_carriage_candidate.gd").new()
 stage.add_child(cart)
 var point: Interactable = cart.get_node("RearPassengerRightBoarding")
 for i in 15: await physics_frame
 overlay.set_target(point,.35)
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png("res://docs/world/captures/cart_interaction_prompt.png") == OK)
 print("CART INTERACTION CAPTURE: PASS")
 quit()
