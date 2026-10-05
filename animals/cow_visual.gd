extends RefCounted
## Godot importer retains COLOR_0 but leaves its albedo flag off for this GLB.
static func apply(cow:Node3D)->void:
	for mesh:MeshInstance3D in cow.find_children("*","MeshInstance3D",true,false):
		for index in mesh.mesh.get_surface_count():
			var source:=mesh.get_active_material(index) as StandardMaterial3D
			if source==null:continue
			var kind:=-1
			var name_lower:=str(mesh.name).to_lower()
			if name_lower=="muzzle":kind=0
			elif "curved horn" in name_lower:kind=1
			elif "cloven hoof" in name_lower:kind=2
			elif "ear inner" in name_lower:kind=3
			if kind>=0:
				var surface:=ShaderMaterial.new();surface.shader=preload("res://animals/cow_surface.gdshader")
				surface.set_shader_parameter("base_color",source.albedo_color);surface.set_shader_parameter("surface_kind",kind)
				mesh.set_surface_override_material(index,surface);continue
			if not "grey coat" in source.resource_name:continue
			var arrays:=mesh.mesh.surface_get_arrays(index)
			var has_colors:bool=arrays[Mesh.ARRAY_COLOR]!=null and not arrays[Mesh.ARRAY_COLOR].is_empty()
			var material:=ShaderMaterial.new();material.shader=preload("res://animals/cow_coat.gdshader")
			material.set_shader_parameter("vertex_coat",has_colors)
			mesh.set_surface_override_material(index,material)
