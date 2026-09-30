"""Derive two editable wealthy-household previews from the existing MPFB rig."""
import bpy, sys, json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
role=sys.argv[sys.argv.index('--')+1]
source=root/'WorkingAssets/NPCs/village_farmer/village_farmer_motion_candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
colors={'landowner':(.70,.65,.50,1),'merchant':(.42,.29,.20,1)}
for obj in bpy.data.objects:
 if obj.type!='MESH': continue
 for slot in obj.material_slots:
  mat=slot.material
  if mat is None: continue
  name=mat.name.lower()
  if any(k in name for k in ['cotton','dhoti','head cloth']):
   mat=mat.copy(); slot.material=mat; mat.diffuse_color=colors[role]
   if mat.use_nodes:
    bs=mat.node_tree.nodes.get('Principled BSDF')
    if bs:
     base=bs.inputs['Base Color']
     for link in list(base.links): mat.node_tree.links.remove(link)
     base.default_value=colors[role]
     bs.inputs['Roughness'].default_value=.75
out=root/f'WorkingAssets/NPCs/households/{role}'; out.mkdir(parents=True,exist_ok=True)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(out/f'{role}.blend'))
# Bake evaluated rest geometry, including morphs and garment masks, then retain skinning.
for rig in bpy.data.objects:
 if rig.type=='ARMATURE':rig.data.pose_position='REST'
bpy.context.view_layer.update()
depsgraph=bpy.context.evaluated_depsgraph_get()
for obj in list(bpy.data.objects):
 if obj.type!='MESH':continue
 mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph),preserve_all_data_layers=True,depsgraph=depsgraph)
 obj.data=mesh
 for mod in list(obj.modifiers):
  if mod.type!='ARMATURE':obj.modifiers.remove(mod)
runtime=root/'characters/npcs/households';runtime.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(runtime/f'{role}.glb'),export_format='GLB',export_skins=True,export_animations=False,export_cameras=False,export_lights=False)
(out/'manifest.json').write_text(json.dumps({'role':role,'donor':str(source.relative_to(root)),'status':'derived household costume candidate; not final likeness or period approval'},indent=2)+'\n')
