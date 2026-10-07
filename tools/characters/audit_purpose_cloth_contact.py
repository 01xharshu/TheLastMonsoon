"""Sample actual corrected source cloth against complete posed body surfaces."""
import bpy,sys,json,math
from pathlib import Path
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
import argparse,hashlib
parser=argparse.ArgumentParser()
parser.add_argument('role',nargs='?',default='all',choices=['all','dock_porter','boatman','record_clerk'])
parser.add_argument('--source',type=Path)
parser.add_argument('--output',type=Path,default=None)
parser.add_argument('--clip',choices=['idle','walk','seat_entry'],default='walk')
parser.add_argument('--substeps',type=int,default=1)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
if args.substeps<1:parser.error('Substeps must be positive')
if args.source and args.role=='all':parser.error('Source override requires a single role')
roles=['dock_porter','boatman','record_clerk'] if args.role=='all' else [args.role]
clip=args.clip;substeps=args.substeps;sources={}
report={}
for role in roles:
 source=args.source or ROOT/f'WorkingAssets/NPCs/{role}/{role}_motion_candidate.blend'
 sources[role]={'path':str(source),'sha256':hashlib.sha256(source.read_bytes()).hexdigest()}
 bpy.ops.wm.open_mainfile(filepath=str(source))
 rig=bpy.data.objects[role+'_rig'];body=bpy.data.objects[role+'_MakeHuman_body'];rig.animation_data.action=bpy.data.actions[clip];rig.data.pose_position='POSE'
 names=['Opaque fitted underwear foundation','Fitted cotton upper base','Knee length wrapped dhoti','Dhoti woven border','Wide madder waist sash','Narrow indigo waist binding','Porter fitted short work trousers','Clerk full length trousers','Clerk buttoned sleeveless waistcoat']
 cloth=[bpy.data.objects[n] for n in names if n in bpy.data.objects]
 corrected=[o for o in cloth if o.data.shape_keys and o.data.shape_keys.key_blocks.get(('Seat' if clip=='seat_entry' else 'Walk')+' cloth 00')] if clip!='idle' else []
 for obj in cloth:
  if obj.data.shape_keys:
   for key in obj.data.shape_keys.key_blocks:
    if key.name.startswith(('Walk cloth','Seat cloth')):key.value=0
 result={o.name:{'max_penetration_m':0,'penetrating_samples':0,'worst_point':None,'vertex_samples':0,'face_center_samples':0,'nearest_body_regions':{}} for o in cloth}
 for sample_index in range((36 if clip=='walk' else 60)*substeps+1):
  frame=1+sample_index/substeps
  phase=(frame-1)/(36 if clip=='walk' else 60)
  prefix='Seat cloth ' if clip=='seat_entry' else 'Walk cloth '
  for obj in corrected:
   samples=sum(key.name.startswith(prefix) for key in obj.data.shape_keys.key_blocks)
   sample=phase*(samples-1 if clip=='seat_entry' else samples);first=min(int(sample),samples-1) if clip=='seat_entry' else int(sample)%samples;fraction=sample-math.floor(sample)
   for i in range(samples):obj.data.shape_keys.key_blocks[prefix+'%02d'%i].value=(1-fraction if i==first else fraction if i==(min(first+1,samples-1) if clip=='seat_entry' else (first+1)%samples) else 0)
  bpy.context.scene.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();ev=body.evaluated_get(dg);mesh=ev.to_mesh()
  tree=BVHTree.FromPolygons([ev.matrix_world@v.co for v in mesh.vertices],[list(p.vertices) for p in mesh.polygons]);body_regions=[]
  group_names={g.index:g.name for g in body.vertex_groups}
  for polygon in mesh.polygons:
   weights={}
   for index in polygon.vertices:
    for group in mesh.vertices[index].groups:
     name=group_names.get(group.group,'unknown')
     if name in rig.data.bones:weights[name]=weights.get(name,0)+group.weight
   body_regions.append(max(weights,key=weights.get) if weights else 'unknown')
  ev.to_mesh_clear()
  for obj in cloth:
   ev=obj.evaluated_get(dg);mesh=ev.to_mesh();points=[ev.matrix_world@v.co for v in mesh.vertices]
   points += [ev.matrix_world@p.center for p in mesh.polygons]
   for sample_index,point in enumerate(points):
    nearest,normal,polygon,distance=tree.find_nearest(point)
    depth=-(point-nearest).dot(normal)
    if depth>.002:
     result[obj.name]['penetrating_samples']+=1
     kind='vertex_samples' if sample_index<len(mesh.vertices) else 'face_center_samples'
     result[obj.name][kind]+=1
     region=body_regions[polygon]
     regions=result[obj.name]['nearest_body_regions'];regions[region]=regions.get(region,0)+1
     if depth>result[obj.name]['max_penetration_m']:
      result[obj.name]['max_penetration_m']=depth;result[obj.name]['worst_point']={'frame':frame,'point':list(point),'sample_kind':kind,'nearest_body_region':region,'nearest_body_point':list(nearest)}
   ev.to_mesh_clear()
 report[role]=result
 print('CLOTH_CONTACT',role,json.dumps(result),flush=True)
output=args.output
passed=all(v['penetrating_samples']==0 for actor in report.values() for v in actor.values())
payload=json.dumps({'sources':sources,'passed':passed,'substeps_per_frame':substeps,'clip':clip,'scope':'source '+clip+' vertex and polygon-center surface sampling; not full continuous mesh or renderer approval','actors':report},indent=2)+'\n'
if output:output.write_text(payload)

raise SystemExit(0 if passed else 1)
