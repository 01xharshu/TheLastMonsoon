"""Shorten only the retained MPFB ponytail into a tied-back style."""
import bpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
p=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend';bpy.ops.wm.open_mainfile(filepath=str(p));bpy.context.preferences.filepaths.save_version=0
hair=bpy.data.objects['Farmer_hair'];backup=hair.copy();backup.data=hair.data.copy();backup.name='Retained unshortened MPFB hair';backup['street_source_only']=True;backup.hide_render=True;bpy.context.collection.objects.link(backup);backup.hide_set(True)
inv=hair.matrix_world.inverted();head=hair.vertex_groups.get('head');count=0
for v in hair.data.vertices:
 point=hair.matrix_world@v.co
 if point.z>=1.32:continue
 point.z=1.32+(point.z-1.32)*.30;v.co=inv@point
 if head:
  for group in hair.vertex_groups:group.remove([v.index])
  head.add([v.index],1,'REPLACE')
 count+=1
hair.data.update();hair['individual_style']='short tied-back MPFB ponytail';bpy.ops.wm.save_as_mainfile(filepath=str(p));print('CANDIDATE_TIED_HAIR',slug,'vertices',count,flush=True)
