"""Swap isolated candidate brow to another bundled MPFB asset."""
import bpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from whole_body_contract import retain_complete_body
args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
bpy.ops.preferences.addon_enable(module='bl_ext.blender_org.mpfb')
from bl_ext.blender_org.mpfb.services.humanservice import HumanService
path=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend';bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
old=bpy.data.objects['Candidate eyebrows'];old.name='Retained prior candidate eyebrows';old['street_source_only']=True;old.hide_render=True;old.hide_set(True)
folder=Path.home()/'Library/Application Support/Blender/5.2/extensions/.user/blender_org/mpfb/data/eyebrows/eyebrow008'
brow=HumanService.add_mhclo_asset(str(folder/'eyebrow008.mhclo'),body,asset_type='Eyebrows',subdiv_levels=0);brow.name='Candidate eyebrows'
mat=old.data.materials[0].copy();tex=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE');tex.image=bpy.data.images.load(str(folder/'eyebrow008.png'),check_existing=True);tex.image.pack();brow.data.materials.clear();brow.data.materials.append(mat)
retain_complete_body(body);bpy.ops.wm.save_as_mainfile(filepath=str(path));print('CANDIDATE_BROW_SWAP',slug,len(brow.data.vertices),flush=True)
