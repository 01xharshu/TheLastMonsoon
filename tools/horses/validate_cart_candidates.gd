extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var script: Script = load("res://vehicles/horse_cart_candidate.gd")
	var labels := ["PassengerBench","ProduceBundle"]
	for i in 2:
		var cart: Node3D = script.new()
		cart.variant = i
		root.add_child(cart)
		if cart.wheels.size() != 2 or cart.horse_animation == null:
			push_error("CART CANDIDATE BLOCKED: missing wheel or draft horse rig")
			quit(1)
			return
		for required in ["DraftShaft","LeatherTrace",labels[i]]:
			if cart.find_child(required,true,false) == null:
				push_error("CART CANDIDATE BLOCKED: missing " + required)
				quit(1)
				return
		var before: float = cart.wheels[0].rotation.x
		cart.set_forward_motion(3.0,.5)
		if cart.wheels[0].rotation.x <= before or cart.horse_animation.current_animation != "AnimalArmature|Walk":
			push_error("CART CANDIDATE BLOCKED: wheel and draft horse did not respond to motion")
			quit(1)
			return
		cart.queue_free()
	print("CART CANDIDATES: PASS | two distinct bodies, shafts, traces, rigged draft horse, wheel and walk response")
	quit()
