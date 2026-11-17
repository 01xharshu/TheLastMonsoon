"""Add an MPFB hair asset to an isolated adult candidate, preserving prior hair."""
import bpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from whole_body_contract import retain_complete_body
args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1];style=args[args.index('--style')+1]
if style not in ('long01','ponytail01','braid01','short01','short02','short03','short04'):raise ValueError('Unsupported retained MPFB style')
path=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend';bpy.ops.preferences.addon_enable(module='bl_ext.blender_org.mpfb')
from bl_ext.blender_org.mpfb.services.humanservice import HumanService
bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
old=bpy.data.objects['Farmer_hair'];old.name='Retained previous candidate hair';old['street_source_only']=True;old.hide_render=True;old.hide_set(True)
data=Path.home()/'Library/Application Support/Blender/5.2/extensions/.user/blender_org/mpfb/data/hair'/style/(style+'.mhclo')
hair=HumanService.add_mhclo_asset(str(data),body,asset_type='Hair',subdiv_levels=0)
hair.name='Farmer_hair';hair.data.materials.clear();hair.data.materials.append(old.data.materials[0]);hair['individual_style']=style
retain_complete_body(body);bpy.ops.wm.save_as_mainfile(filepath=str(path));print('CANDIDATE_MPFB_HAIR',slug,style,'vertices',len(hair.data.vertices),flush=True)
