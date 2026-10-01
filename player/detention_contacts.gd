extends RefCounted
## Original small cord cuffs follow wrists; no imported asset or skin override.
var root: Node3D
var cuffs: Array[MeshInstance3D] = []
var link: MeshInstance3D
func setup(visual: Node3D) -> void:
	root=Node3D.new()
	root.name="DetentionCord"
	visual.add_child(root)
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=Color(.37,.28,.15)
	mat.roughness=.96
	for side in 2:
		var mesh:=MeshInstance3D.new()
		var shape:=TorusMesh.new()
		shape.inner_radius=.028
		shape.outer_radius=.038
		shape.rings=16
		shape.ring_segments=8
		mesh.mesh=shape
		mesh.material_override=mat
		root.add_child(mesh)
		cuffs.append(mesh)
	link=MeshInstance3D.new()
	var shape:=CylinderMesh.new()
	shape.top_radius=.005
	shape.bottom_radius=.005
	shape.radial_segments=8
	link.mesh=shape
	link.material_override=mat
	root.add_child(link)
	root.hide()
func update(visual: Node3D) -> void:
	if root==null: setup(visual)
	var action: String=visual.actor.get_meta("detention_action","")
	root.visible=action in ["arrest","escort"] and float(visual.actor.get_meta("detention_blend",0.0))>.90
	if not root.visible:return
	var wrists: Array[Vector3]=[]
	for entry in [["l",0],["r",1]]:
		var side: String=entry[0]
		var hand: Vector3=visual.skeleton.get_bone_global_pose(visual.bones["hand_"+side]).origin
		var elbow: Vector3=visual.skeleton.get_bone_global_pose(visual.bones["lowerarm_"+side]).origin
		var wrist: Vector3=visual.skeleton.to_global(hand)
		var direction: Vector3=visual.skeleton.global_basis*(hand-elbow).normalized()
		cuffs[entry[1]].global_transform=Transform3D(Basis(Quaternion(Vector3.UP,direction)),wrist)
		wrists.append(wrist)
	var axis: Vector3=wrists[1]-wrists[0]
	link.global_position=(wrists[0]+wrists[1])*.5
	link.global_basis=Basis(Quaternion(Vector3.UP,axis.normalized()))
	(link.mesh as CylinderMesh).height=axis.length()
