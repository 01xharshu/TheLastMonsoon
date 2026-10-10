extends "res://world/suryagarh/landscape_layout.gd"
## Sample the saved rendered triangles, rather than a smoother procedural approximation.
var tiles: Dictionary = {}
func configure(land: Node3D) -> void:
	for tile in land.get_node("TerrainTiles").get_children():
		var parts:=str(tile.name).split("_")
		var mesh:MeshInstance3D=tile
		tiles[Vector2i(int(parts[1]),int(parts[2]))]=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
func height(x:float,z:float) -> float:
	var key:=Vector2i(int(floor((x+HALF)/TILE)),int(floor((z+HALF)/TILE)))
	if not tiles.has(key):return super.height(x,z)
	var origin:=Vector2(-HALF+key.x*TILE,-HALF+key.y*TILE)
	return preload("res://world/suryagarh/grass_blades.gd").baked_frame(tiles[key],origin,Vector2(x,z),STEP,TILE).origin.y
