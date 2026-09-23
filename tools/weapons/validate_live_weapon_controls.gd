extends SceneTree
## Gameplay wiring check; the rejected character export is never captured or approved.
class DamageDummy extends StaticBody3D:
	var damage := 0.0
	func take_damage(amount: float) -> void:
		damage += amount

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 5: await process_frame
	var actor: CharacterBody3D = world.get_node("Player")
	var equipment: Node3D = actor.get_node("VisualRoot/CharacterVisual").equipment
	var camera: Camera3D = actor.get_node("CameraPivot/SpringArm3D/Camera3D")
	actor.inventory.add_item("bow",1)
	actor.inventory.add_item("arrow",3)
	actor.inventory.add_item("pistol",1)
	actor.inventory.add_item("pistol_ball",6)
	equipment.select_weapon(2)
	equipment.stowed = false
	equipment._refresh()
	assert(equipment.bow_hand.visible and not equipment.bow_back.visible)
	var bow: Node = actor.get_node("BowCombat")
	bow.aiming = true
	bow.draw_fraction = 1.0
	equipment.bow_hand.set_draw_fraction(1.0)
	var before: int = actor.inventory.get_item_count("arrow")
	assert(bow.fire())
	assert(bow.arrows_fired == 1 and actor.inventory.get_item_count("arrow") == before-1)
	var flying: Node3D
	for child in world.get_children():
		if child.get_script() == load("res://environment/weapons/period_arrow/arrow_projectile.gd"):
			flying = child
	assert(flying != null and flying.active)
	var dummy := DamageDummy.new()
	world.add_child(dummy)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5,2.0,.35)
	collision.shape = box
	dummy.add_child(collision)
	dummy.global_position = flying.global_position + flying.velocity.normalized()*7.0
	for i in 20: await physics_frame
	assert(dummy.damage >= 35.0 and flying.hit_count == 1)
	equipment.select_weapon(3)
	equipment._refresh()
	assert(equipment.pistol_hand.visible and not equipment.pistol_hip.visible)
	var pistol: Node = actor.get_node("PistolCombat")
	pistol.aiming = true
	var rounds_before: int = pistol.rounds
	assert(pistol.fire())
	assert(pistol.shots_fired == 1 and pistol.rounds == rounds_before-1)
	assert(pistol.start_reload())
	pistol._process(4.0)
	assert(pistol.rounds == 5 and actor.inventory.get_item_count("pistol_ball") == 5)
	print("LIVE WEAPONS: PASS | bow hold/draw/fire/hit, pistol hold/aim/fire/reload")
	quit()
