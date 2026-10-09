"""Remove redundant action keys with a bounded garment-position error.

Dry-run by default. --apply updates the retained source, runtime, sampled pose
input and matching runtime timeline. Body geometry and walking keys are kept.
"""
import bpy,json,sys
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from river_asset_export import export_river_asset
LIMIT=.0015
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/river_woman/river_woman_motion.blend'))
bpy.context.preferences.filepaths.save_version=0
data=json.loads((ROOT/'WorkingAssets/NPCs/river_woman/poses.json').read_text())
actions=[pose for pose in data['poses'] if 'slope' not in pose]
objects=[bpy.data.objects[name] for name in ['Fitted cotton upper base','Wrapped sari lower drape','Sari lower border','Woven sari pallu over blouse','Opaque fitted bra and thong foundation']]
count=sum(len(obj.data.vertices) for obj in objects)
values=np.empty((len(actions),count,3),dtype=np.float32)
for index,pose in enumerate(actions):
 offset=0
 for obj in objects:
  n=len(obj.data.vertices);flat=np.empty(n*3,dtype=np.float32)
  obj.data.shape_keys.key_blocks[pose['key']].data.foreach_get('co',flat)
  values[index,offset:offset+n]=flat.reshape(n,3);offset+=n
protect={0.0,10.0,12.0,15.0,17.2,20.0,23.0,29.0,35.0,38.0,43.0,48.0,51.0,52.25,55.0,65.0,68.0,72.0}
kept={index for index,pose in enumerate(actions) if any(abs(pose['time']-time)<.00001 for time in protect)}|{0,len(actions)-1}
times=np.asarray([pose['time'] for pose in actions]);anchors=sorted(kept)
stack=list(zip(anchors,anchors[1:]));worst=0.0
while stack:
 left,right=stack.pop()
 if right-left<2:continue
 fraction=((times[left+1:right]-times[left])/(times[right]-times[left])).astype(np.float32)
 desired=values[left,None]+(values[right]-values[left])[None]*fraction[:,None,None]
 error=np.square(values[left+1:right]-desired).sum(axis=2).max(axis=1)
 index=int(np.argmax(error))+left+1
 if error[index-left-1]>LIMIT*LIMIT:
  kept.add(index);stack.extend([(left,index),(index,right)])
 else:worst=max(worst,float(np.sqrt(error.max())))
kept=sorted(kept)
print('RIVER_PRUNE action_keys',len(actions),'to',len(kept),'maximum_removed_error_m',worst,flush=True)
if '--apply' not in sys.argv:raise SystemExit(0)
retained_names={actions[index]['key'] for index in kept}
for obj in objects:
 for key in list(obj.data.shape_keys.key_blocks):
  if key.name.startswith('River cloth ') and key.name not in retained_names:obj.shape_key_remove(key)
 for index in kept:obj.data.shape_keys.key_blocks[actions[index]['key']].name='Retained river action '+str(index)
 for new_index,old_index in enumerate(kept):obj.data.shape_keys.key_blocks['Retained river action '+str(old_index)].name='River cloth %03d'%new_index
poses=[]
for new_index,old_index in enumerate(kept):
 pose=actions[old_index].copy();pose['key']='River cloth %03d'%new_index;poses.append(pose)
poses.extend(pose for pose in data['poses'] if 'slope' in pose)
data['poses']=poses
(ROOT/'WorkingAssets/NPCs/river_woman/poses.json').write_text(json.dumps(data))
timeline='extends RefCounted\n## Bounded-error action samples; walking uses separate slope/phase keys.\nconst TIMES := '+repr([actions[index]['time'] for index in kept])+'\n'
(ROOT/'characters/npcs/indian/river_cloth_timeline.gd').write_text(timeline)
rig=bpy.data.objects['village_woman_rig'];body=bpy.data.objects['village_woman_MakeHuman_body']
export_river_asset(ROOT,rig,body,894)
