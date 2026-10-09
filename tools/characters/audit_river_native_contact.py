"""Audit disposable Godot river surfaces against the complete skin volume."""
import sys,json
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from purpose_cloth_volume import VolumeSurface,inside_surface
folder=Path(sys.argv[sys.argv.index('--')+1]);summary={}
for path in sorted(folder.glob('*.json')):
 data=json.loads(path.read_text());vertices=[];faces=[]
 for body in data['body']:
  offset=len(vertices);vertices.extend(body['vertices']);ids=body['indices']
  reverse=body.get('winding_sign',1)<0
  faces.extend(tuple(offset+i for i in (reversed(ids[j:j+3]) if reverse else ids[j:j+3])) for j in range(0,len(ids),3))
 if not vertices or not faces:raise RuntimeError('Missing full native river body')
 tree=VolumeSurface.FromPolygons(vertices,faces,all_triangles=True)
 result=summary.setdefault(data['role'],{'samples':0,'violations':0,'worst_mm':0,'garments':{},'vertex_violations':0,'face_violations':0,'ground_violations':0,'seated_rear_hip_gaps_m':[]})
 if 'seated_rear_hip_gap_m' in data:
  gap=data['seated_rear_hip_gap_m'];result['seated_rear_hip_gaps_m'].append(gap)
  if gap<-.002 or gap>.015:result['ground_violations']+=1
 for garment in data['garments']:
  points=[Vector(point) for point in garment['vertices']];ids=garment['indices'];count=len(points)
  points += [sum((points[index] for index in ids[j:j+3]),Vector())/3 for j in range(0,len(ids),3)]
  cloth=result['garments'].setdefault(garment['name'],{'violations':0,'worst_mm':0})
  for index,point in enumerate(points):
   _,_,_,distance=tree.find_nearest(point);result['samples']+=1
   if distance>.002 and inside_surface(tree,point):
    result['violations']+=1;cloth['violations']+=1
    result['vertex_violations' if index<count else 'face_violations']+=1
    result['worst_mm']=max(result['worst_mm'],distance*1000)
    if distance*1000>cloth['worst_mm']:
     cloth['worst_mm']=distance*1000
     cloth['worst_pose']={'walking':data['walking'],'sample':data['sample'],'label':data['label'],'point':list(point),'active_keys':garment.get('active_keys',[])}
for role,result in summary.items():print('NATIVE_CONTACT',role,json.dumps(result),flush=True)
raise SystemExit(0 if summary and all(result['violations']==0 and result['ground_violations']==0 for result in summary.values()) else 1)
