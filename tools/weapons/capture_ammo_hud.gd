extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
 if DisplayServer.get_name() == "headless": quit(1); return
 root.size = Vector2i(1280,720)
 var world := Node3D.new()
 root.add_child(world)
 var time := Node.new()
 time.name = "GameTimeSystem"
 time.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
 world.add_child(time)
 var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
 actor.position = Vector3(0,1,0)
 world.add_child(actor)
 await create_timer(.2).timeout
 var gear: Node = actor.get_node("VisualRoot/CharacterVisual").equipment
 actor.inventory.add_item("enfield",1)
 actor.inventory.add_item("paper_cartridges",8)
 gear.select_weapon(1)
 gear.stowed = false
 gear._refresh()
 var gun: Node = actor.get_node("RifleCombat")
 gun.rounds = 1
 await create_timer(.3).timeout
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png("res://docs/world/captures/ammo_hud_enfield.png") == OK)
 actor.inventory.add_item("pistol",1)
 actor.inventory.add_item("pistol_ball",8)
 gear.select_weapon(3)
 gear.stowed = false
 gear._refresh()
 var pistol: Node = actor.get_node("PistolCombat")
 pistol.rounds = 2
 await create_timer(.3).timeout
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png("res://docs/world/captures/ammo_hud_adams.png") == OK)
 actor.inventory.add_item("double_gun",1)
 actor.inventory.add_item("shot_charge",8)
 gear.select_weapon(5)
 gear.stowed = false
 gear._refresh()
 var double_gun: Node = actor.get_node("DoubleGunCombat")
 double_gun.rounds = 2
 await create_timer(.3).timeout
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png("res://docs/world/captures/ammo_hud_double_gun.png") == OK)
 print("AMMO HUD CAPTURE: PASS")
 quit()
