extends RefCounted
static func apply(actor: Node) -> void:
 for mesh in actor.find_children("*","MeshInstance3D",true,false):
  for surface in mesh.mesh.get_surface_count():
   var original:=mesh.get_active_material(surface) as StandardMaterial3D
   if original==null: continue
   var label:=original.resource_name.to_lower()
   var material:=ShaderMaterial.new()
   if "police puttee cloth" in label:
    material.shader=preload("res://characters/npcs/thana/patrol_uniform/police_puttee.gdshader")
    material.set_shader_parameter("cloth_color",Color(.57,.43,.26))
   elif "sikh uncut beard" in label:
    material.shader=preload("res://characters/npcs/thana/patrol_uniform/police_beard.gdshader")
    material.set_shader_parameter("hair_color",Color(.018,.012,.008))
   elif "police drab cotton" in label or "police tan fittings" in label:
    material.shader=preload("res://characters/npcs/thana/patrol_uniform/police_cloth.gdshader")
    material.set_shader_parameter("cloth_color",Color(.62,.47,.29) if "drab" in label else Color(.57,.43,.26))
   else: continue
   mesh.set_surface_override_material(surface,material)
