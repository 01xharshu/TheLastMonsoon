extends Node3D
## Worn river path and startup-only grass clearance; surrounding growth is retained.
const Ground = preload("res://world/suryagarh/tree_trunk_collision.gd")
const Startup = preload("res://systems/world_startup.gd")
var points: Array[Vector3] = []
var cells := {}
var grass_removed := 0
const WIDTH := 2.3
const CELL := 8.0

func _ready() -> void:
	name="RiverAccessFootpath"
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in points.size()-1:
		var a:=points[index];var b:=points[index+1]
		var tangent:=Vector2(b.x-a.x,b.z-a.z)
		if tangent.length()<.01:continue
		var side:=Vector3(-tangent.y,0,tangent.x).normalized()*1.8
		for corner in [a-side,a+side,b-side,a+side,b+side,b-side]:
			st.set_normal(Vector3.UP);st.add_vertex(corner+Vector3.UP*.035)
		var from:=Vector2(minf(a.x,b.x)-WIDTH,minf(a.z,b.z)-WIDTH)
		var to:=Vector2(maxf(a.x,b.x)+WIDTH,maxf(a.z,b.z)+WIDTH)
		for x in range(floori(from.x/CELL),floori(to.x/CELL)+1):
			for z in range(floori(from.y/CELL),floori(to.y/CELL)+1):
				var cell:=Vector2i(x,z)
				if not cells.has(cell):cells[cell]=[]
				cells[cell].append(index)
	var path:=MeshInstance3D.new();path.name="WornEarthPath";path.mesh=st.commit()
	var earth:=StandardMaterial3D.new();earth.albedo_color=Color(.35,.29,.20);earth.roughness=1.0
	path.material_override=earth;path.visibility_range_end=300;path.visibility_range_end_margin=25;add_child(path)
	clear_grass.call_deferred()

func reserved(point: Vector2) -> bool:
	for index: int in cells.get(Vector2i(floori(point.x/CELL),floori(point.y/CELL)),[]):
		var a:=Vector2(points[index].x,points[index].z);var b:=Vector2(points[index+1].x,points[index+1].z)
		var ab:=b-a
		if ab.length_squared()<.0001:continue
		if point.distance_squared_to(a+ab*clampf((point-a).dot(ab)/ab.length_squared(),0,1))<=WIDTH*WIDTH:return true
	return false

func clear_grass() -> void:
	var world:=preload("res://systems/world_context.gd").find_world(self)
	if world==null:return
	var nature:=world.get_node_or_null("Landscape/NatureTiles")
	if nature==null:return
	for batch: MultiMeshInstance3D in nature.find_children("Grass*","MultiMeshInstance3D",true,false):
		var bounds:=batch.get_aabb()
		var center:=batch.to_global(bounds.get_center())
		if center.x< -430 or center.x>200 or center.z<30 or center.z>330:continue
		await Startup.checkpoint(self,"Clearing the river footpath…")
		var transforms:=Ground.instance_transforms(batch.multimesh)
		var copy: MultiMesh
		for index in transforms.size():
			if is_zero_approx(transforms[index].basis.determinant()):continue
			var at:=batch.to_global(transforms[index].origin)
			if not reserved(Vector2(at.x,at.z)):continue
			if copy==null:copy=Ground.copy_instances(batch.multimesh)
			copy.set_instance_transform(index,Transform3D(Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO),transforms[index].origin));grass_removed+=1
		if copy!=null:batch.multimesh=copy
	set_meta("grass_cleared",true);set_meta("grass_removed",grass_removed)
