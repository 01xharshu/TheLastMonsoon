"""Add MPFB eyebrow and eyelash assets to an isolated adult candidate."""
import bpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from whole_body_contract import retain_complete_body
args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
path=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend'
bpy.ops.preferences.addon_enable(module='bl_ext.blender_org.mpfb')
from bl_ext.blender_org.mpfb.services.humanservice import HumanService
bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
base=Path.home()/'Library/Application Support/Blender/5.2/extensions/.user/blender_org/mpfb/data'
assets=[('eyebrows','eyebrow008')] if '--brows-only' in args else [('eyebrows','eyebrow008'),('eyelashes','eyelashes01')]
for kind,name in assets:
 if bpy.data.objects.get('Candidate '+kind):raise RuntimeError('Already has '+kind)
 folder=base/kind/name;obj=HumanService.add_mhclo_asset(str(folder/(name+'.mhclo')),body,asset_type=kind.title(),subdiv_levels=0)
 obj.name='Candidate '+kind;material=bpy.data.materials.new('Candidate dark '+kind);material.use_nodes=True
 shader=material.node_tree.nodes.get('Principled BSDF');texture=material.node_tree.nodes.new('ShaderNodeTexImage');texture.image=bpy.data.images.load(str(folder/(name+'.png')),check_existing=True);texture.image.pack()
 material.node_tree.links.new(texture.outputs['Color'],shader.inputs['Base Color']);material.node_tree.links.new(texture.outputs['Alpha'],shader.inputs['Alpha']);shader.inputs['Roughness'].default_value=.8;material.surface_render_method='DITHERED'
 obj.data.materials.clear();obj.data.materials.append(material);obj['source']='Bundled MPFB '+name
 print('MPFB_FACE_DETAIL',slug,kind,len(obj.data.vertices),flush=True)
retain_complete_body(body);bpy.ops.wm.save_as_mainfile(filepath=str(path))
