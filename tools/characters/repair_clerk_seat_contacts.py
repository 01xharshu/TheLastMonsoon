"""Repair existing isolated seat keys, then export without changing body data."""
import bpy,sys,runpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
print('CLERK_REPAIR_MODE', 'smooth' if '--smooth' in sys.argv else 'contact',flush=True)
source=ROOT/'WorkingAssets/NPCs/record_clerk/desk_study/record_clerk_seat.blend'
bpy.ops.wm.open_mainfile(filepath=str(source));rig=bpy.data.objects['record_clerk_rig'];body=bpy.data.objects['record_clerk_MakeHuman_body']
rig.animation_data.action=bpy.data.actions['seat_entry'];rig.data.pose_position='POSE'
cloth=[bpy.data.objects[name] for name in ['Opaque fitted underwear foundation','Clerk full length trousers','Clerk buttoned sleeveless waistcoat','Fitted cotton upper base']]
from purpose_seat_contact_repair import fit_seat_contacts
samples=[int(value) for value in sys.argv[sys.argv.index('--samples')+1].split(',')] if '--samples' in sys.argv else None
fit_seat_contacts(rig,body,cloth,ROOT/'characters/npcs/review/record_clerk_seat.glb',samples=samples,smooth="--smooth" in sys.argv)
bpy.context.scene.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(source))
sys.argv.append('--export-only');runpy.run_path(str(ROOT/'tools/characters/refit_clerk_seat_layers.py'),run_name='__main__')
