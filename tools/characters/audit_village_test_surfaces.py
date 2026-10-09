"""Check temporary actual Godot skin/morph surfaces using Blender's native BVH."""
import sys,json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
folder=Path(sys.argv[sys.argv.index('--')+1]);summary={}
for path in sorted(folder.glob('*.json')):
 data=json.loads(path.read_text());vertices=[];faces=[]
 for body in data['body']:
  offset=len(vertices);vertices.extend(body['vertices']);ids=body['indices']
  # Godot winding is measured against its imported outward normals.
  reverse=body.get('winding_sign',1)<0
  faces.extend(tuple(offset+index for index in (reversed(ids[i:i+3]) if reverse else ids[i:i+3])) for i in range(0,len(ids),3))
 if not vertices or not faces:raise RuntimeError('Missing native body: '+str(path))
 tree=BVHTree.FromPolygons(vertices,faces,all_triangles=True)
 result=summary.setdefault(data['role'],{'samples':0,'violations':0,'worst_mm':0,'garments':{}})
 for garment in data['garments']:
  points=[Vector(point) for point in garment['vertices']];ids=garment['indices']
  points += [sum((points[index] for index in ids[i:i+3]),Vector())/3 for i in range(0,len(ids),3)]
  cloth=result['garments'].setdefault(garment['name'],{'violations':0,'worst_mm':0})
  for point in points:
   near,normal,_,distance=tree.find_nearest(point)
   depth=(near-point).dot(normal)
   result['samples']+=1
   if depth>.002:
    result['violations']+=1;cloth['violations']+=1
    result['worst_mm']=max(result['worst_mm'],depth*1000);
    if depth*1000>cloth['worst_mm']:
     cloth['worst_mm']=depth*1000
     cloth['worst_pose']={'walking':data['walking'],'sample':data['sample'],'point':list(point),'active_keys':garment.get('active_keys',[])}
for role,result in summary.items():print('NATIVE_CONTACT',role,json.dumps(result),flush=True)
raise SystemExit(0 if summary and all(r['violations']==0 for r in summary.values()) else 1)
