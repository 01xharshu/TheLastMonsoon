"""Fit exported transition samples over the same intact blended source physique."""
import bpy,json,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from village_cloth_fit import _fit_pose,sample_faces
from village_interpolation_fit import tree_for,refine
from village_clothing_export import export_fitted
folder=Path(sys.argv[sys.argv.index('--')+1])
for role in ['village_farmer','village_weaver_assistant']:
 source=ROOT/'WorkingAssets/NPCs'/role/(role+'_clothing_fitted.blend')
 bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.preferences.filepaths.save_version=0
 rig=bpy.data.objects[role+'_rig'];body=bpy.data.objects[role+'_MakeHuman_body']
 objects=[o for o in bpy.data.objects if o.type=='MESH' and o.data.shape_keys and o.data.shape_keys.key_blocks.get('idle fit 001')]
 for track in rig.animation_data.nla_tracks:track.mute=True
 for obj in objects:
  keys=obj.data.shape_keys;keys.animation_data.action=None
  for track in keys.animation_data.nla_tracks:track.mute=True
 samples=[]
 for path in sorted(folder.glob(role+'_*.json')):
  data=json.loads(path.read_text());active=data['garments'][0]['active_keys']
  clips={name.split()[0] for name,weight in active if weight>.0001}
  if len(clips)==2:samples.append(data)
 count=0
 for sweep in range(3):
  for data in samples:
   groups={}
   for name,weight in data['garments'][0]['active_keys']:
    clip=name.split()[0];frame=int(name.rsplit(' ',1)[1]);groups.setdefault(clip,[]).append((frame,weight))
   poses={};amount={}
   for clip,values in groups.items():
    amount[clip]=sum(weight for frame,weight in values);frame=sum(frame*weight for frame,weight in values)/amount[clip]
    rig.animation_data.action=bpy.data.actions[clip];bpy.context.scene.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update()
    poses[clip]={b.name:(b.location.copy(),b.rotation_quaternion.copy(),b.scale.copy()) for b in rig.pose.bones}
   rig.animation_data.action=None
   fraction=amount['walk']/sum(amount.values())
   for bone in rig.pose.bones:
    a=poses['idle'][bone.name];b=poses['walk'][bone.name]
    bone.location=a[0].lerp(b[0],fraction);bone.rotation_quaternion=a[1].slerp(b[1],fraction);bone.scale=a[2].lerp(b[2],fraction)
   active={}
   for obj in objects:
    keys=obj.data.shape_keys.key_blocks
    for key in keys:
     if key.name!='Basis':key.value=0
    entry=next(g for g in data['garments'] if g['name']==obj.name)
    active[obj]=[]
    for name,weight in entry['active_keys']:
     keys[name].value=weight;active[obj].append(keys[name])
   bpy.context.view_layer.update();skin=tree_for(body)
   for obj in objects:
    tree=tree_for(body,[bpy.data.objects['Knee length wrapped dhoti']]) if obj.name=='Kurta loose lower panel' else skin
    ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
    points=[ev.matrix_world@v.co for v in mesh.vertices]+[ev.matrix_world@(sum((mesh.vertices[i].co for i in face),Vector())/len(face)) for face in sample_faces(mesh)]
    hit=any((near-point).dot(normal)>.001 for point in points for near,normal,_,distance in [tree.find_nearest(point)])
    ev.to_mesh_clear()
    if hit:_fit_pose(rig,obj,tree,active[obj]);count+=1
  print('TRANSITION_FIT',role,sweep,count,flush=True)
 # Recheck endpoint and interpolation constraints after moving shared pose keys.
 report=json.loads(source.with_name('clothing_fit_manifest.json').read_text())
 report['transition_repairs']=count;report['interpolation_repairs']=refine(rig,body,objects,fit_layers=False)
 export_fitted(ROOT,role,rig,body,report)
