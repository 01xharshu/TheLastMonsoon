extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var carriage: Node3D = load("res://vehicles/family_carriage_candidate.gd").new()
	root.add_child(carriage)
	if carriage.wheels.size() != 4 or carriage.horse_animations.size() != 2:
		push_error("FAMILY CARRIAGE BLOCKED: expected four wheels and two draft horses")
		quit(1)
		return
	if carriage.seat_sockets.size() != 5 or carriage.seat_world("CoachmanSeat").distance_to(carriage.seat_world("RearPassengerLeft")) < 1.0:
		push_error("FAMILY CARRIAGE BLOCKED: separate coachman and family seats missing")
		quit(1)
		return
	for name in ["RearCabinSeat","ForwardCabinSeat","IndividualSeatCushion","InteriorFloorMat","InteriorCeilingLiner","InteriorDoorPull","SideGlazing","DoorHinge","LowerBoardingStep","RoofSeam","LowerDoorPanel","DriverCushion","CoachmanCoat","CoachmanHeadBlockout","CentralPole","PoleCrossbar","OutsideTrace","BoardingStep"]:
		if carriage.find_child(name,true,false) == null:
			push_error("FAMILY CARRIAGE BLOCKED: missing " + name)
			quit(1)
			return
	var before: float = carriage.wheels[0].rotation.x
	carriage.set_forward_motion(3.0,.5)
	if carriage.wheels[0].rotation.x <= before or carriage.horse_animations[0].current_animation != "AnimalArmature|Walk":
		push_error("FAMILY CARRIAGE BLOCKED: draft motion not linked")
		quit(1)
		return
	print("FAMILY CARRIAGE: PASS | cabin, four wheels, two horses, separate coachman box and figure, motion response")
	quit()
