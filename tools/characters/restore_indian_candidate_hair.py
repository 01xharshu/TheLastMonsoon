"""Restore retained MPFB hair mesh for a candidate with a damaged hairline."""
import bpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
path=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend';bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
old=bpy.data.objects['Farmer_hair'];reference=bpy.data.objects['Street original MPFB hair']
backup=old.copy();backup.data=old.data.copy();backup.name='Retained cropped candidate hair';backup['street_source_only']=True;backup.hide_render=True;bpy.context.collection.objects.link(backup);backup.hide_set(True)
old.data=reference.data.copy();old['hair_repair']='Restored intact MPFB hair surface; cropped version retained source-only'
bpy.ops.wm.save_as_mainfile(filepath=str(path));print('CANDIDATE_HAIR_RESTORE',slug,len(old.data.vertices),flush=True)
