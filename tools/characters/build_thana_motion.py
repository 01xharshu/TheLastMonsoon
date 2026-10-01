"""Rigged thana motion exports from the same editable MPFB village source.
Original role palette; retain skin weights and attachment bones. No downloads.
"""
import bpy,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from thana_uniform_fit import fit_uniform
SOURCE=ROOT/'WorkingAssets/NPCs/village_farmer/village_farmer_motion_candidate.blend'
for role,color in [('daroga',(.36,.32,.23)),('mohurrir',(.42,.38,.29)),('burkundaz',(.36,.32,.23))]:
 bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
 rig.data.pose_position='REST'
 bpy.context.view_layer.update()
 for obj in list(bpy.context.scene.objects):
  if obj.type!='MESH':continue
  for mat in obj.data.materials:
   if mat and ('cotton' in mat.name.lower() or 'upper base' in obj.name.lower()):
    copy=mat.copy();copy.diffuse_color=(*color,1)
    if copy.use_nodes:
     base=copy.node_tree.nodes['Principled BSDF'].inputs['Base Color']
     for link in list(base.links):copy.node_tree.links.remove(link)
     base.default_value=(*color,1)
    for i,m in enumerate(obj.data.materials):
     if m==mat:obj.data.materials[i]=copy
 body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
 raw=body.copy();raw.data=body.data.copy();raw.name='Uniform unmasked template';bpy.context.collection.objects.link(raw)
 for m in list(raw.modifiers):
  if m.type=='MASK' and m.name!='Hide helpers':raw.modifiers.remove(m)
 # Bake morphs/cloth masks while preserving deform weights and the armature.
 deps=bpy.context.evaluated_depsgraph_get()
 for obj in list(bpy.context.scene.objects):
  if obj.type!='MESH':continue
  armatures=[m for m in obj.modifiers if m.type=='ARMATURE']
  for m in armatures:m.show_viewport=False
 deps.update()
 for obj in list(bpy.context.scene.objects):
  if obj.type!='MESH':continue
  evaluated=obj.evaluated_get(deps)
  mesh=bpy.data.meshes.new_from_object(evaluated,preserve_all_data_layers=True,depsgraph=deps)
  obj.data=mesh
  for modifier in list(obj.modifiers):
   if modifier.type!='ARMATURE':obj.modifiers.remove(modifier)
   else:modifier.show_viewport=True;modifier.show_render=True
 uniform=fit_uniform(rig,role)
 bpy.data.objects.remove(raw,do_unlink=True)
 rig.animation_data_clear()
 dest=ROOT/'WorkingAssets/NPCs/thana_motion'/role
 dest.mkdir(parents=True,exist_ok=True)
 bpy.ops.wm.save_as_mainfile(filepath=str(dest/f'{role}_motion.blend'))
 bpy.ops.export_scene.gltf(filepath=str(ROOT/f'characters/npcs/thana/{role}_motion.glb'),export_format='GLB',export_skins=True,export_animations=False,export_cameras=False,export_lights=False)
 (dest/'manifest.json').write_text(json.dumps({'source':str(SOURCE.relative_to(ROOT)),'body':'existing MPFB village male','license':'same CC0 source; original project clothing','rigged':True,'role':role,'uniform':uniform},indent=2))
