extends SceneTree
## Small construction regression before the actual-world native review.
func _initialize() -> void:run.call_deferred()
func run() -> void:
	create_timer(20).timeout.connect(func():quit(2))
	var stall := Node3D.new();root.add_child(stall)
	var material := StandardMaterial3D.new()
	var detail = preload("res://world/suryagarh/route_and_market_detail.gd").new()
	detail.canopy(stall,material,0)
	assert(stall.has_node("CornerClothTies") and stall.has_node("FoldedCanvasHem"))
	assert(stall.get_node("TensionedClothShade").mesh.get_aabb().end.y>2.5)
	var old_roof := Node3D.new();old_roof.name="ShadeRoof";stall.add_child(old_roof)
	detail.bazaar_roof(stall)
	assert(stall.has_node("PitchedClayRoof") and stall.has_node("RoofRafters"))
	var roof: MeshInstance3D=stall.get_node("PitchedClayRoof")
	assert(is_equal_approx(roof.mesh.get_aabb().end.y,3.86))
	var collision: CollisionShape3D=stall.get_node("PitchedRoofContact").get_child(0)
	assert(collision.shape.get_faces().size()==12 and collision.shape.backface_collision)
	assert(not stall.has_node("ShadeRoof"))
	detail.free();stall.queue_free();await process_frame
	print("MARKET CONSTRUCTION PASS: supported cloth, folded hem, pitched roof and matching contact")
	quit()
