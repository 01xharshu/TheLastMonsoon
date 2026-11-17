"""Trial bundled MPFB high-poly eyes, retaining old candidate eye asset."""
import bpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from whole_body_contract import retain_complete_body
args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
bpy.ops.preferences.addon_enable(module='bl_ext.blender_org.mpfb')
from bl_ext.blender_org.mpfb.services.humanservice import HumanService
path=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend';bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
old=bpy.data.objects['Farmer_eyes'];old.name='Retained low poly eyes';old['street_source_only']=True;old.hide_render=True;old.hide_set(True)
data=Path.home()/'Library/Application Support/Blender/5.2/extensions/.user/blender_org/mpfb/data/eyes/high-poly/high-poly.mhclo'
eyes=HumanService.add_mhclo_asset(str(data),body,asset_type='Eyes',subdiv_levels=0);eyes.name='Farmer_eyes';eyes.data.materials.clear()
for mat in old.data.materials:eyes.data.materials.append(mat)
retain_complete_body(body);bpy.ops.wm.save_as_mainfile(filepath=str(path));print('CANDIDATE_MPFB_EYES',slug,len(eyes.data.vertices),flush=True)
