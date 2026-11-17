"""Vary isolated adult male candidate headwear; retain editable prior garments."""
import bpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
if slug not in ('male_02','male_04'):raise ValueError('No style authored for '+slug)
path=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend';bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
removed=[]
for obj in bpy.data.objects:
 if obj.type!='MESH':continue
 if obj.name.startswith('Fitted turban') or (slug=='male_04' and obj.name.startswith('Bordered shoulder shawl')):
  obj['street_source_only']=True;obj.hide_render=True;obj.hide_set(True);removed.append(obj.name)
if len(removed)<3:raise RuntimeError('Expected retained turban pieces missing')
bpy.ops.wm.save_as_mainfile(filepath=str(path));print('MALE_STYLE',slug,'source_only',removed,flush=True)
