extends "res://vehicles/horse_cart_candidate.gd"
## Reuse the established goods-cart construction without animals, riders or vehicle logic.
func _ready() -> void:
	_build()
	set_process(false)
	visual_root.position.z = -2.55
	for node in visual_root.get_children():
		if node.name.begins_with("ProduceBundle") or node.name.begins_with("LeatherTrace") or node.name == "LoadTie": node.queue_free()
	if not wheels.is_empty():
		wheels[0].position.x -= .55
		wheels[0].position.y = .12
		wheels[0].rotation.z = 1.2
	var sides := visual_root.find_children("SlattedSide*","MeshInstance3D",true,false)
	if not sides.is_empty(): sides[0].rotation.z = -.35
	var body := StaticBody3D.new()
	body.name = "RemainingDeckCollision"
	add_child(body)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8,.3,2.5)
	collision.shape = box
	collision.position = Vector3(0,1.08,.2)
	body.add_child(collision)
