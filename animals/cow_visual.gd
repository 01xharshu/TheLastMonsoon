extends RefCounted
## Godot importer retains COLOR_0 but leaves its albedo flag off for this GLB.
static func apply(cow:Node3D)->void:
	for mesh:MeshInstance3D in cow.find_children("*","MeshInstance3D",true,false):
		for index in mesh.mesh.get_surface_count():
			var source:=mesh.get_active_material(index) as StandardMaterial3D
			if source==null or not "grey coat" in source.resource_name:continue
			var arrays:=mesh.mesh.surface_get_arrays(index)
			var has_colors:bool=arrays[Mesh.ARRAY_COLOR]!=null and not arrays[Mesh.ARRAY_COLOR].is_empty()
			var material:=ShaderMaterial.new();material.shader=preload("res://animals/cow_coat.gdshader")
			material.set_shader_parameter("vertex_coat",has_colors)
			mesh.set_surface_override_material(index,material)
