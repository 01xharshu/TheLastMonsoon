"""Retain ill-fitting lashes as source-only until facial fit is corrected."""
import bpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
p=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend';bpy.ops.wm.open_mainfile(filepath=str(p));bpy.context.preferences.filepaths.save_version=0
obj=bpy.data.objects['Candidate eyelashes'];obj['street_source_only']=True;obj.hide_render=True;obj.hide_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(p));print('LASH_SOURCE_ONLY',slug,flush=True)
