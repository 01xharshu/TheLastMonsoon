"""Move loose MPFB hair away from back clothing while retaining scalp position."""
import bpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
path=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend';bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
hair=bpy.data.objects['Farmer_hair']
if bpy.data.objects.get('Retained loose hair before fabric clearance'):raise RuntimeError('Already adjusted')
backup=hair.copy();backup.data=hair.data.copy();backup.name='Retained loose hair before fabric clearance';backup['street_source_only']=True;backup.hide_render=True;bpy.context.collection.objects.link(backup);backup.hide_set(True)
inverse=hair.matrix_world.inverted();maximum=0
for v in hair.data.vertices:
 p=hair.matrix_world@v.co;t=max(0,min(1,(1.42-p.z)/.18));t=t*t*(3-2*t);shift=.065*t;p.y+=shift;v.co=inverse@p;maximum=max(maximum,shift)
hair.data.update();hair['cloth_clearance']='Smooth bounded offset behind clothing; scalp retained'
bpy.ops.wm.save_as_mainfile(filepath=str(path));print('HAIR_BACK_CLEARANCE',slug,'maximum_mm',maximum*1000,flush=True)
