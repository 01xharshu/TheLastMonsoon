extends SceneTree
var failed := false
func _initialize() -> void: _run.call_deferred()
func check(value: bool, message: String) -> void:
 if not value:
  failed = true
  push_error(message)
func _run() -> void:
 var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
 root.add_child(world)
 current_scene = world
 var actor: CharacterBody3D = world.get_node("Player")
 actor.global_position = Vector3(-230,50,180)
 var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
 var gear: Node = visual.equipment
 var gun: Node = actor.get_node("DoubleGunCombat")
 gun.set_process(false)
 actor.inventory.add_item("double_gun",1)
 actor.inventory.add_item("shot_charge",4)
 gear.select_weapon(5)
 gear.stowed = false
 gear._refresh()
 check(gear.double_hand.visible,"Double gun did not appear in Arjun's hands")
 check(gun.capacity()==2 and gun.ammo_id()=="shot_charge","Double gun ammunition contract is wrong")
 Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
 for i in 4: await physics_frame
 gun.start_reload()
 check(gun.reload_remaining>0 and actor.inventory.get_item_count("shot_charge")==2,"Two chambers were not loaded")
 gun._process(5.0)
 check(gun.rounds==2,"Double gun did not finish loading")
 gun.aiming = true
 gun.fire()
 check(gun.rounds==1 and gun.shots_fired==1,"First barrel did not fire")
 gun.aiming = true
 gun.fire()
 check(gun.rounds==0 and gun.shots_fired==2,"Second barrel did not fire")
 gun.aiming = true
 gun.fire()
 check(gun.rounds==0 and gun.shots_fired==2,"Empty gun fired")
 gun.start_reload()
 gun._process(5.0)
 check(gun.rounds==2 and actor.inventory.get_item_count("shot_charge")==0,"Reload did not consume the spare charges")
 print("DOUBLE GUN: ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
