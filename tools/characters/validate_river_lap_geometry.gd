extends SceneTree
## Compare actual emitted sari vertices to the original all-sphere envelope.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var stage:=Node3D.new();root.add_child(stage)
	var woman=preload("res://characters/npcs/indian/river_woman_study.gd").new()
	woman.home=Vector3.ZERO;woman.bank=Vector3(0,0,-4);stage.add_child(woman);woman.set_process(false)
	var optimized: RefCounted=woman.sari_drape
	var source:=FileAccess.get_file_as_string("res://characters/npcs/indian/river_sari_drape.gd")
	var start:=source.find("func _init(");var finish:=source.find("func _point(")
	source=source.substr(0,start)+"func _init() -> void: pass\n\n"+source.substr(finish)
	var local_start:=source.find("\t\tfor row in range(1,rings):")
	var local_finish:=source.find("\tvar hem_heights",local_start)
	source=source.substr(0,local_start)+"\t\tfor row in range(1,rings):\n\t\t\tfor i in segments:radii[row][i]=maxf(radii[row][i],(radii[row-1][i]+radii[row+1][i])*.5)\n"+source.substr(local_finish)
	var old_loop:="""				for sphere in spheres:
					var horizontal:float=Vector2(point.x-sphere.x,point.z-sphere.z).length()
					var safe_radius:float=sphere.w+float(DIMENSIONS.clearance)+.016
					if horizontal<safe_radius:
						lap_top=maxf(lap_top,sphere.y+sqrt(safe_radius*safe_radius-horizontal*horizontal)+.008)
"""
	start=source.find("\t\t\t\tfor sphere: Vector4 in lap_cells")
	finish=source.find("\t\t\t\tpoint.y=",start)
	if start<0 or finish<0:push_error("Expected optimized lap envelope missing");quit(1);return
	source=source.substr(0,start)+old_loop+source.substr(finish)
	var baseline_script:=GDScript.new();baseline_script.source_code=source
	if baseline_script.reload()!=OK:quit(1);return
	var baseline: RefCounted=baseline_script.new()
	for property in ["actor","rig","pieces","directions","planes","plane_rays","segments","rings"]:baseline.set(property,optimized.get(property))
	var worst:=0.0;var vertices:=0;var poses:=0
	for slope in [-.3375,0.0,.3375]:
		woman.ground_height=func(_x:float,z:float)->float:return -z*slope
		for time in [1.37,10.0,17.2,24.37,29.37,39.0,43.0,48.25,52.25,65.25]:
			woman.sample(time);optimized.update()
			var actual: Array[PackedVector3Array]=[]
			for piece in optimized.pieces:actual.append(piece.node.get_meta("river_sari_points").duplicate())
			baseline.update()
			for i in baseline.pieces.size():
				var expected:PackedVector3Array=baseline.pieces[i].node.get_meta("river_sari_points")
				for j in expected.size():worst=maxf(worst,expected[j].distance_to(actual[i][j]));vertices+=1
			optimized.update();poses+=1
	print("RIVER_LAP_GEOMETRY ",JSON.stringify({"poses":poses,"vertices":vertices,"max_difference_m":worst,"passed":worst<.000002}))
	stage.free();quit(0 if worst<.000002 else 1)
