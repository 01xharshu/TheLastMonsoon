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
  assert(actor.interaction_overlay.marker_world_positions.has(pickup), "Weapon interaction card has no visible anchor: " + weapon_id)
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
  assert_visible_weapon(gear, weapon_id)
 for weapon_id in slots:
  gear.select_weapon(slots[weapon_id])
  assert_visible_weapon(gear, weapon_id)
 var owned_pickup = load("res://world/suryagarh/settlements/weapon_pickup.gd").new()
 owned_pickup.weapon_id = "talwar"
 world.add_child(owned_pickup)
 owned_pickup.global_position = actor.global_position + Vector3(0,0,1)
 gear.stowed = true
 gear._refresh()
 owned_pickup.interact(actor)
 assert(gear.selected == slots["talwar"] and not gear.stowed)
 assert_visible_weapon(gear, "talwar")
 owned_pickup.queue_free()
 gear.toggle_stowed()
 assert_visible_weapon(gear, "")
 print("EQUIP HOLD: PASS | all five store weapons")
 quit()

func assert_visible_weapon(gear: Node, expected: String) -> void:
 var held := {"talwar":gear.talwar_hand,"enfield":gear.enfield_hand,"bow":gear.bow_hand,"pistol":gear.pistol_hand,"double_gun":gear.double_hand,"utility_knife":gear.knife_hand}
 for weapon_id in held:
  assert(held[weapon_id].visible == (weapon_id == expected), "Wrong held weapon visible: " + weapon_id)
 for carried in [gear.talwar_waist,gear.enfield_back,gear.bow_back,gear.quiver_back,gear.pistol_hip,gear.knife_hip,gear.double_back]:
  assert(not carried.visible, "Unequipped carried weapon remained visible: " + carried.name)
