extends SceneTree
## Validate the actual renderer buffer, rather than only the CPU contact envelope.
func _initialize() -> void:run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=="headless":push_error("Native renderer required for cloth buffer readback");quit(2);return
	var stage:=Node3D.new();root.add_child(stage);current_scene=stage
	var woman=preload("res://characters/npcs/indian/river_woman_study.gd").new()
	woman.home=Vector3.ZERO;woman.bank=Vector3(0,0,-4);stage.add_child(woman);woman.set_process(false)
	var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(2,2,2);camera.look_at(Vector3(0,.8,0));camera.current=true
	var gap:=0.0;var normal_gap:=0.0;var samples:=0
	for time in [1.37,17.2,29.37,43.37,48.25,52.25,65.25]:
		woman.sample(time)
		await process_frame;RenderingServer.force_draw(false)
		for piece in woman.sari_drape.pieces:
			var mesh:ArrayMesh=piece.mesh
			var expected:PackedVector3Array=piece.node.get_meta("river_sari_points")
			var actual:Array=mesh.surface_get_arrays(0)
			var vertices:PackedVector3Array=actual[Mesh.ARRAY_VERTEX]
			var normals:PackedVector3Array=actual[Mesh.ARRAY_NORMAL]
			if samples==0:print("RIVER_DRAPE_BUFFER_FORMAT ",piece.node.name," normal_offset=",RenderingServer.mesh_surface_get_format_offset(mesh.surface_get_format(0),expected.size(),Mesh.ARRAY_NORMAL)," normal_stride=",RenderingServer.mesh_surface_get_format_normal_tangent_stride(mesh.surface_get_format(0),expected.size()))
			for i in expected.size():
				gap=maxf(gap,expected[i].distance_to(vertices[i]))
				var row:int=i/woman.sari_drape.segments;var segment:int=i%woman.sari_drape.segments
				var across:Vector3=expected[row*woman.sari_drape.segments+(segment+1)%woman.sari_drape.segments]-expected[row*woman.sari_drape.segments+(segment+woman.sari_drape.segments-1)%woman.sari_drape.segments]
				var up:Vector3=expected[maxi(0,row-1)*woman.sari_drape.segments+segment]-expected[mini(piece.rows,row+1)*woman.sari_drape.segments+segment]
				normal_gap=maxf(normal_gap,up.cross(across).normalized().distance_to(normals[i]))
			samples+=expected.size()
	var passed:bool=gap<.000001 and normal_gap<.0002
	print("RIVER_DRAPE_BUFFERS ",JSON.stringify({"passed":passed,"poses":7,"vertices":samples,"max_vertex_gap_m":gap,"max_normal_gap":normal_gap}))
	stage.free();quit(0 if passed else 1)
