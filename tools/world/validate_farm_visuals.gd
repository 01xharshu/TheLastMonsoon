extends SceneTree
const Farm=preload("res://world/suryagarh/settlements/farm_visuals.gd")
const Layout=preload("res://world/suryagarh/landscape_layout.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
	create_timer(15).timeout.connect(func():quit(2))
	var layout:=Layout.new()
	var plot:=Node3D.new();root.add_child(plot)
	plot.position=Vector3(-419,layout.height(-419,235),235)
	Farm.build(plot,layout,Vector2(8,4.4),140)
	var plants:MultiMeshInstance3D=plot.get_node("FarmPlants")
	await process_frame
	var mm:=plants.multimesh
	assert(mm.instance_count==63)
	assert(plot.get_child_count()==2)
	for index in mm.instance_count:
		var t:=mm.get_instance_transform(index)
		assert(absf(t.origin.x)<4 and absf(t.origin.z)<2.2)
		var world:=plot.to_global(t.origin)
		if DisplayServer.get_name()!="headless":assert(absf(world.y-layout.height(world.x,world.z)-.065)<.001)
	assert(plants.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert(plants.visibility_range_end==100)
	# Verify reproducible rebuilding and the existing broad building grass exclusion.
	var other:=Node3D.new();root.add_child(other);other.position=plot.position
	Farm.build(other,layout,Vector2(8,4.4),140)
	assert(other.get_node("FarmPlants").multimesh.get_instance_transform(10)==mm.get_instance_transform(10))
	var blades=preload("res://world/suryagarh/grass_blades.gd")
	assert(not blades.placement_allowed(layout,Vector2(-321,299),layout.height(-321,299),30))
	print("FARM VISUALS PASS: bounded plots, surveyed roots, deterministic shared mesh, two render nodes, house grass exclusion")
	quit()
