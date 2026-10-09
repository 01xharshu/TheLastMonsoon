extends SceneTree
## Isolated input lifecycle test; no captures, files or saved settings.
class Inventory:
	extends Node
	var opened := false
	func is_open() -> bool: return opened
class Actor:
	extends Node
	var inventory_ui := Inventory.new()
	var camera_pivot := Node3D.new()
	var camera_pitch := 0.0
	var mouse_sensitivity := 0.0025
	var min_camera_angle := -60.0
	var max_camera_angle := 60.0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(load("res://player/player.tscn") is PackedScene, "player scene integration loads")
	var actor := Actor.new()
	root.add_child(actor)
	actor.set_physics_process(true)
	actor.add_child(actor.inventory_ui)
	actor.add_child(actor.camera_pivot)
	var layer := CanvasLayer.new()
	actor.add_child(layer)
	var controls = load("res://ui/mobile/touch_controls.gd").new()
	layer.add_child(controls)
	controls.enabled = true
	controls.show()
	await process_frame
	controls.move_stick(controls.stick_center + Vector2(controls.radius, 0))
	await process_frame
	assert(Input.is_action_pressed("move_right"), "joystick movement")
	assert(not Input.is_action_pressed("move_left"), "opposite movement released")
	var press := InputEventScreenTouch.new()
	press.index = 2
	press.pressed = true
	press.position = controls.button_rects[0].get_center()
	controls._input(press)
	await process_frame
	assert(Input.is_action_pressed("jump") and Input.is_action_pressed("move_right"), "simultaneous jump and movement")
	controls.look_drag(Vector2(50, 10000))
	assert(actor.camera_pivot.rotation.y < 0 and is_equal_approx(actor.camera_pitch, deg_to_rad(-60)), "look and pitch clamp")
	press.pressed = false
	controls._input(press)
	await process_frame
	assert(not Input.is_action_pressed("jump"), "touch release")
	actor.inventory_ui.opened = true
	controls._process(0)
	await process_frame
	assert(not Input.is_action_pressed("move_right") and controls.fingers.is_empty(), "menu releases input")
	actor.inventory_ui.opened = false
	controls.set_action("sprint", 1)
	await process_frame
	controls._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	assert(not Input.is_action_pressed("sprint"), "focus loss releases input")
	controls.move_stick(controls.stick_center)
	assert(controls.joystick == Vector2.ZERO, "joystick deadzone")
	controls.set_action("aim", 1)
	await process_frame
	controls.release_all()
	await process_frame
	assert(not Input.is_action_pressed("aim"), "held aim cleanup")
	if "--review-output" in OS.get_cmdline_user_args():
		var args := OS.get_cmdline_user_args()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[args.find("--review-output") + 1])
	actor.free()
	print("PASS mobile movement, simultaneous buttons, camera, release, menu and focus cleanup")
	quit()
