extends SceneTree

class IconBoard extends Control:
	const Assets = preload("res://interaction/collection_icon_assets.gd")
	const FONT = preload("res://assets/ui/fonts/MFBOldstyle-Regular.otf")
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("242321"))
		draw_string(FONT, Vector2(30,42), "Collection icons — detail and HUD size", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("f4eddf"))
		var names: Array = Assets.TEXTURES.keys()
		for i in range(names.size()):
			var p := Vector2(30 + (i % 5) * 184, 68 + (i / 5) * 148)
			var texture: Texture2D = Assets.TEXTURES[names[i]]
			draw_texture_rect(texture,Rect2(p,Vector2(64,64)),false)
			draw_texture_rect(texture,Rect2(p+Vector2(86,20),Vector2(26,26)),false)
			draw_string(FONT,p+Vector2(0,94),str(names[i]).replace("_", " ").capitalize(),HORIZONTAL_ALIGNMENT_LEFT,175,18,Color("f4eddf"))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(960,550)
	var board := IconBoard.new()
	root.add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/world/captures/collection_icon_detail.png") == OK)
	print("COLLECTION ICON BOARD: captured")
	quit()
