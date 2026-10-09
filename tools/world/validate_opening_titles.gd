extends SceneTree
## Native/headless typography, timing and aspect checks; captures stay opt-in.
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func run() -> void:
	root.get_node("SaveManager").options.fullscreen = false
	root.get_node("SaveManager").apply_options()
	var opening = load("res://story/opening_sequence.gd").new()
	root.add_child(opening)
	opening.set_process(false)
	opening.set_process_input(false)
	opening._build_overlay()
	check(opening.shade.color == Color.BLACK,"First card frame exposes world")
	var total := 0.0
	for card in opening.titles.CARDS: total += float(card[1])
	check(is_equal_approx(total,opening.Titles.DURATION),"Card duration drifts from sequence")
	for size in [Vector2i(1280,720),Vector2i(720,1280),Vector2i(1920,800)]:
		root.size = size
		root.content_scale_size = size
		for frame in 3: await process_frame
		for t in [3.0,9.0,17.0,24.0,31.0,38.0,46.0,52.0]:
			opening.titles.update(t)
			for frame in 2: await process_frame
			check(opening.titles.modulate.a > .9,"Card is unreadable during hold")
			if t == 52.0:
				check(opening.titles.title_top.visible and opening.titles.title_main.visible,"Stacked game title missing")
				check(opening.titles.title_main.get_theme_font_size("font_size") > opening.titles.title_top.get_theme_font_size("font_size")*2,"MONSOON is not substantially larger")
			var label: Label = opening.titles.title_main if t == 52.0 else opening.titles
			check(label.get_minimum_size().x <= label.size.x+1,"Text overflows width")
			check(label.get_minimum_size().y <= label.size.y+1,"Text overflows height")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var folder := OS.get_environment("TLM_OPENING_TEST_OUTPUT")
				if folder != "": root.get_texture().get_image().save_png(folder+"/title_%dx%d_%02d.png"%[size.x,size.y,int(t)])
		opening.titles.next_morning(2.0)
		check(opening.titles.text == "The next morning" and not opening.titles.title_main.visible,"Dawn card leaves title visible")
	print("OPENING TITLES: ","FAIL" if failed else "PASS"," | eight cards, studio credit, stacked title, dawn card, landscape/portrait/ultrawide")
	preload("res://tools/test_audio_cleanup.gd").finish(self,1 if failed else 0)
