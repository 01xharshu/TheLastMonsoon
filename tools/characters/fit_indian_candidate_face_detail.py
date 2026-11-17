"""Fit MPFB brow and lash accessories just outside unchanged adult skin."""
import bpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from street_female_garments import body_volume
from whole_body_contract import retain_complete_body
args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
path=ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend';bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='REST';body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
for mod in body.modifiers:
 if mod.type=='MASK':mod.show_viewport=False
bpy.context.view_layer.update();skin=body_volume(body)
for name in ['Candidate eyebrows','Candidate eyelashes']:
 obj=bpy.data.objects.get(name)
 if obj is None:continue
 backup=obj.copy();backup.data=obj.data.copy();backup.name='Retained unfit '+name;backup['street_source_only']=True;backup.hide_render=True;bpy.context.collection.objects.link(backup);backup.hide_set(True)
 inverse=obj.matrix_world.inverted();worst=0.0
 for vertex in obj.data.vertices:
  point=obj.matrix_world@vertex.co
  if name=='Candidate eyebrows':point.z+=.01
  near,normal,_,_=skin.find_nearest(point)
  if near is None:raise RuntimeError('Skin surface lookup failed')
  gap=(point-near).dot(normal);shift=max(0.0,.003-gap)
  if shift>.01:raise RuntimeError('Facial accessory correction too large')
  point+=normal*shift;vertex.co=inverse@point;worst=max(worst,shift)
 obj.data.update();print('FACIAL_ACCESSORY_FIT',slug,name,'max_mm',worst*1000,flush=True)
retain_complete_body(body);bpy.ops.wm.save_as_mainfile(filepath=str(path))
