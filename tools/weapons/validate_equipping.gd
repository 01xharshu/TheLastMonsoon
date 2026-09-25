extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
 var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
 root.add_child(world)
 var actor: CharacterBody3D = world.get_node("Player")
 var store: Node3D = world.get_node("Settlement/CompanyArmoury")
 var gear: Node = actor.get_node("VisualRoot/CharacterVisual").equipment
 for i in 8: await physics_frame
 var pickups: Array[Node3D] = []
 for p in store.find_children("*","StaticBody3D",true,false):
  if p.is_in_group("weapon_pickups"): pickups.append(p)
 assert(pickups.size() == 5)
 var slots := {"talwar":0,"enfield":1,"bow":2,"pistol":3,"double_gun":5}
 for pickup in pickups:
  var weapon_id: String = pickup.weapon_id
  actor.global_position = pickup.to_global(Vector3(0,-.25,1.7))
  var flat: Vector3 = pickup.global_position-actor.global_position
  flat.y = 0
  actor.get_node("VisualRoot").global_rotation.y = atan2(flat.x,flat.z)
  for i in 4: await physics_frame
  assert(actor._find_interactable() == pickup)
  actor._begin_interaction_hold(pickup,"interact")
  Input.action_press("interact")
  for i in 65: await physics_frame
  Input.action_release("interact")
  assert(actor.inventory.has_item(weapon_id))
  assert(gear.selected == slots[weapon_id] and not gear.stowed)
  gear.stowed = true
  gear._refresh()
  gear.select_weapon(slots[weapon_id])
  assert(not gear.stowed)
 print("EQUIP HOLD: PASS | all five store weapons")
 quit()
