"""Smooth source-only candidate foundation boundaries; preserve prior garment."""
import bpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from street_female_garments import smooth_hems
args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
path=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend';bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
obj=bpy.data.objects['Opaque fitted bra and thong foundation']
if bpy.data.objects.get('Foundation prior to hem smoothing'):raise RuntimeError('Already smoothed')
backup=obj.copy();backup.data=obj.data.copy();backup.name='Foundation prior to hem smoothing';backup['street_source_only']=True;backup.hide_render=True;bpy.context.collection.objects.link(backup);backup.hide_set(True)
for iteration in range(5):smooth_hems(obj)
obj['edge_note']='Smoothed fabric boundaries; prior foundation retained source-only'
bpy.ops.wm.save_as_mainfile(filepath=str(path));print('FOUNDATION_EDGE_SMOOTHED',slug,flush=True)
