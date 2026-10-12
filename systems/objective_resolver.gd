extends RefCounted
## One priority contract for existing guidance consumers; layout remains theirs.
static func resolve(actor: Node3D, include_manual := true) -> Dictionary:
	if actor.get_meta("opening_active",false) or actor.get_meta("story_cinematic",false): return {}
	if actor.get_meta("morning_tutorial_active",false):
		var tutorial:=actor.get_node_or_null("UI/HUDRoot/MorningTutorial")
		if tutorial!=null and tutorial.step==10 and is_instance_valid(tutorial.horse):
			return {"position":tutorial.horse.global_position+Vector3.UP*1.2,"label":"Arjun’s horse","endpoint":"","objective":"","owner":"tutorial"}
		return {}
	var world:=actor.get_parent()
	var map:=actor.get_node_or_null("UI/WorldMap")
	if include_manual and map!=null and not map.follow_story and map.waypoint.is_finite():
		var ground:float=world.layout.height(map.waypoint.x,map.waypoint.y)
		return {"position":Vector3(map.waypoint.x,ground+1.5,map.waypoint.y),"label":str(map.selected_site) if map.selected_site!="" else "Map destination","endpoint":"","objective":"Go to the marked destination","owner":"manual"}
	var rebellion:=world.get_node_or_null("RebellionStory")
	if rebellion!=null and rebellion.stage not in ["dormant","complete"]:
		var result: Dictionary=rebellion.destination().duplicate()
		if not result.is_empty(): result.merge({"objective":rebellion.objective(),"owner":"rebellion"},true)
		return result
	var errands:=world.get_node_or_null("ErrandSystem")
	if errands!=null and not errands.active.is_empty():
		var result: Dictionary=errands.destination().duplicate()
		if not result.is_empty(): result.merge({"objective":errands.tracked_objective(),"owner":"errand"},true)
		return result
	var community:=world.get_node_or_null("CommunityStory")
	if community!=null:
		var result: Dictionary=community.destination().duplicate()
		if not result.is_empty():
			result.merge({"objective":community.objective(),"owner":"community"},true)
			return result
	var inquiry:=world.get_node_or_null("DevInquiry")
	if inquiry!=null and inquiry.configured and inquiry.stage!="dormant" and is_instance_valid(inquiry.destination):
		var label:=str(inquiry.destination.get_meta("parking_label",""))
		if not label.is_empty():
			var objective:=str(inquiry.objective.text)
			var story:=world.get_node_or_null("DevStory")
			if story!=null and story.state in ["farm","complete"]: objective=story.objective.text
			return {"position":inquiry.destination.global_position,"label":label,"endpoint":"","objective":objective,"owner":"story"}
	if include_manual and errands!=null:
		var result: Dictionary=errands.destination().duplicate()
		if not result.is_empty(): result.merge({"objective":"Go to the marked destination","owner":"manual"},true)
		return result
	return {}
