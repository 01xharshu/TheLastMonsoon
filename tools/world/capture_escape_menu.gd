extends SceneTree
class EmptyInventory extends Node:
	func is_open() -> bool: return false
class ReviewPlayer extends CharacterBody3D:
	var inventory_ui := EmptyInventory.new()
	func _exit_tree() -> void: inventory_ui.free()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := Node3D.new()
	var player := ReviewPlayer.new()
	player.name = "Player"
	var ui := CanvasLayer.new()
	ui.name = "UI"
	player.add_child(ui)
	var hud := Control.new()
	hud.name = "HUDRoot"
	ui.add_child(hud)
	var map := Control.new()
	map.name = "WorldMap"
	map.set_script(load("res://player/world_map.gd"))
	ui.add_child(map)
	world.add_child(player)
	root.add_child(world)
	var menu := CanvasLayer.new()
	menu.name = "GameMenu"
	menu.set_script(load("res://ui/game_menu.gd"))
	world.add_child(menu)
	menu.open()
	for tab in ["map","game","settings"]:
		menu.select_tab(tab)
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/escape_%s.png" % tab)
	menu.close()
	world.queue_free()
	for i in 3: await process_frame
	print("ESCAPE MENU NATIVE CAPTURES COMPLETE")
	quit()
