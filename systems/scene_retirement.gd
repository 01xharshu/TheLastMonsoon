extends RefCounted
## Keep mesh/material owners alive until their rendering instances have retired.
class Resources extends RefCounted:
	var meshes:Array[Mesh]=[]
	var materials:Array[Material]=[]
	func _init(scene:Node)->void:
		for node:GeometryInstance3D in scene.find_children("*","GeometryInstance3D",true,false):
			if node.material_override!=null:materials.append(node.material_override)
			if node.material_overlay!=null:materials.append(node.material_overlay)
			if node is MeshInstance3D and node.mesh!=null:
				meshes.append(node.mesh)
				for surface in node.mesh.get_surface_count():
					var material:Material=node.get_surface_override_material(surface)
					if material!=null:materials.append(material)
			elif node is MultiMeshInstance3D and node.multimesh!=null and node.multimesh.mesh!=null:
				meshes.append(node.multimesh.mesh)

static func hold_until_exit(tree:SceneTree,scene:Node)->void:
	if not is_instance_valid(scene) or not scene.is_inside_tree():return
	var held:=Resources.new(scene)
	await scene.tree_exited
	for frame in 3:await tree.process_frame
	# Release only after queued instance deletion has reached the renderer.
	held=null

static func retire_current(tree:SceneTree)->void:
	var scene:Node=tree.current_scene
	if not is_instance_valid(scene):return
	var held:=Resources.new(scene)
	scene.queue_free()
	for frame in 3:await tree.process_frame
	held=null
