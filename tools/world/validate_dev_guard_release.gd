extends SceneTree
## Actual MPFB guards/carry contacts, grounded throw and separated rescue posts.
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world);current_scene=world
	var deadline := Time.get_ticks_msec()+90000
	while (world.get_node_or_null("DevStory")==null or not world.get_node("DevStory").configured) and Time.get_ticks_msec()<deadline:
		await process_frame
	var story:Node=world.get_node_or_null("DevStory")
	if story==null:
		push_error("Station setup did not complete")
		quit(1)
		return
	var opening: Node=world.get_node_or_null("OpeningSequence")
	if opening!=null:
		opening.skip_cinematic()
	story.player.set_meta("document_busy",false)
	story.player.set_meta("opening_active",false)
	story.player.get_node("UI/HUDRoot/MorningTutorial").restore_step(11)
	story.set_process(false)
	check(story.start_inquiry(),"actual inquiry staging starts")
	var worst_contact:=0.0
	var smallest_spacing:=INF
	var worst_ground:=0.0
	for cue in ["collapse","discard","throw","rescue"]:
		for index in story.beats.size():
			if story.beats[index].cue==cue:story.beat_index=index;break
		if cue=="collapse":
			story.player.global_position=story.inquiry.station.to_global(story.CHAMBER_GRAB)
			story.stage_action("beating")
		story.enter_beat()
		var cue_spacing:=INF
		for frame in 60:
			await process_frame
			story.age+=.05
			story.update_acting(.05,clampf(story.age/float(story.beats[story.beat_index].seconds),0,1))
			if cue=="collapse":continue
			var guards:Array=story.inquiry.guards
			smallest_spacing=minf(smallest_spacing,Vector2(guards[0].global_position.x-guards[1].global_position.x,guards[0].global_position.z-guards[1].global_position.z).length())
			cue_spacing=minf(cue_spacing,Vector2(guards[0].global_position.x-guards[1].global_position.x,guards[0].global_position.z-guards[1].global_position.z).length())
			for index in 2:
				var on_floor:Vector3=story.guard_floor_position(guards[index],guards[index].global_position)
				worst_ground=maxf(worst_ground,absf(on_floor.y-guards[index].global_position.y))
			if cue=="discard" and frame>2:worst_contact=maxf(worst_contact,story.carry_contact_error)
		print("DEV GUARD RELEASE SAMPLE ",cue," spacing=",cue_spacing)
		if DisplayServer.get_name()!="headless" and not OS.get_environment("TLM_GLOW_REVIEW").is_empty():
			RenderingServer.force_draw(false)
			var temporary:=OS.get_environment("TLM_STORY_TEST_DIR")
			root.get_texture().get_image().save_png(temporary.path_join("guard_"+cue+".png"))
	check(worst_ground<.015,"carriers remain on actual physical floor")
	check(smallest_spacing>.8,"carrier bodies remain separated")
	check(worst_contact<.06,"real carry palms retain body contact")
	for index in 2:
		var guard:Node3D=story.inquiry.guards[index]
		check(not guard.cinematic_carry and guard.cinematic_palms.is_empty(),"released guard has no stale carry pose")
	print("DEV GUARD RELEASE: ","PASS" if failures.is_empty() else "FAIL"," ground=",worst_ground," spacing=",smallest_spacing," contact=",worst_contact)
	var review := OS.get_environment("TLM_GLOW_REVIEW")
	if DisplayServer.get_name()!="headless" and not review.is_empty():
		print("DEV GUARD RELEASE REVIEW READY")
		var review_deadline := Time.get_ticks_msec()+60000
		while Time.get_ticks_msec()<review_deadline and not FileAccess.file_exists(review.path_join("guard_release_done")):
			await process_frame
	root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
