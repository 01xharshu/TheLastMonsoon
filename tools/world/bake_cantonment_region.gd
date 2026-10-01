extends "res://tools/world/bake_landscape.gd"
## Incremental bake: preserve all other saved terrain, nature, port and material state.
var old_shapes: Dictionary = {}
var cleared := 0
func bake() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("CANTONMENT BAKE requires the native renderer")
		quit(1)
		return
	world = load(OUT+"landscape.scn").instantiate()
	root.add_child(world)
	terrain_material = load(OUT+"terrain_material.tres")
	var terrain: Node3D = world.get_node("TerrainTiles")
	for tz in [8,9]:
		for tx in [8,9,10]:
			var tile: Node3D = terrain.get_node("Terrain_%02d_%02d" % [tx,tz])
			old_shapes[Vector2i(tx,tz)] = tile.get_node("GroundCollision/CollisionShape3D").shape
			terrain.remove_child(tile)
			tile.free()
			bake_tile(Vector2(-Layout.HALF+tx*Layout.TILE,-Layout.HALF+tz*Layout.TILE),tx,tz,terrain)
	var plot: Dictionary = Layout.PLOTS.BritishCantonment
	var route: Array = Layout.ROUTES.cantonment_approach
	for batch in world.get_node("NatureTiles").find_children("*","MultiMeshInstance3D",true,false):
		var original: MultiMesh = batch.multimesh
		var changed := false
		var copy: MultiMesh
		for i in original.instance_count:
			var t := original.get_instance_transform(i)
			var p: Vector3 = batch.global_transform*t.origin
			var edge := maxf(absf(p.x-plot.center.x)-plot.half.x,absf(p.z-plot.center.y)-plot.half.y)
			var road := INF
			for j in range(route.size()-1): road = minf(road,layout.segment_distance(Vector2(p.x,p.z),route[j],route[j+1]))
			if edge >= 22 and road >= 9: continue
			if not changed:
				copy = original.duplicate()
				changed = true
			if edge < 8 or road < 9:
				t.basis = Basis.IDENTITY.scaled(Vector3.ZERO)
				cleared += 1
			elif edge < 22:
				t.origin.y += layout.height(p.x,p.z)-old_height(p.x,p.z)
			copy.set_instance_transform(i,t)
		if changed: batch.multimesh = copy
	for body in world.get_node("NatureTiles").find_children("*","StaticBody3D",true,false):
		var p: Vector3 = body.global_position
		var edge := maxf(absf(p.x-plot.center.x)-plot.half.x,absf(p.z-plot.center.y)-plot.half.y)
		var road := INF
		for j in range(route.size()-1): road = minf(road,layout.segment_distance(Vector2(p.x,p.z),route[j],route[j+1]))
		if edge < 8 or road < 9:
			body.get_parent().remove_child(body)
			body.free()
		elif edge < 22: body.position.y += layout.height(p.x,p.z)-old_height(p.x,p.z)
	# Add the new lane to the current mask without rebuilding existing roads.
	var image: Image = (load(OUT+"road_mask.res") as Texture2D).get_image()
	var pixels := image.get_width()
	for z in range(int((140+Layout.HALF)/Layout.SIZE*pixels),int((480+Layout.HALF)/Layout.SIZE*pixels)+1):
		for x in range(int((310+Layout.HALF)/Layout.SIZE*pixels),int((580+Layout.HALF)/Layout.SIZE*pixels)+1):
			var p := (Vector2(x+0.5,z+0.5)/pixels-Vector2.ONE*0.5)*Layout.SIZE
			var distance := INF
			for j in range(route.size()-1): distance = minf(distance,layout.segment_distance(p,route[j],route[j+1]))
			image.set_pixel(x,z,Color(maxf(image.get_pixel(x,z).r,1-smoothstep(2.0,4.8,distance)),0,0))
	var mask := ImageTexture.create_from_image(image)
	save_resource(mask,"road_mask.res")
	terrain_material.set_shader_parameter("road_mask_tex",mask)
	save_resource(terrain_material,"terrain_material.tres")
	var packed := PackedScene.new()
	assert(packed.pack(world) == OK)
	save_resource(packed,"landscape.scn")
	print("CANTONMENT REGIONAL BAKE: PASS | six tiles updated, other tiles preserved; cleared ",cleared," nature instances")
	quit()
func old_height(x: float,z: float) -> float:
	var key := Vector2i(int(floor((x+Layout.HALF)/Layout.TILE)),int(floor((z+Layout.HALF)/Layout.TILE)))
	if not old_shapes.has(key): return layout.height(x,z)
	var shape: HeightMapShape3D = old_shapes[key]
	var n := shape.map_width-1
	var step := Layout.TILE/n
	var local := Vector2(x+Layout.HALF-key.x*Layout.TILE,z+Layout.HALF-key.y*Layout.TILE)/step
	var ix := clampi(int(floor(local.x)),0,n-1)
	var iz := clampi(int(floor(local.y)),0,n-1)
	var a := shape.map_data[iz*(n+1)+ix]
	var b := shape.map_data[iz*(n+1)+ix+1]
	var c := shape.map_data[(iz+1)*(n+1)+ix]
	var d := shape.map_data[(iz+1)*(n+1)+ix+1]
	return lerpf(lerpf(a,b,local.x-ix),lerpf(c,d,local.x-ix),local.y-iz)*step
