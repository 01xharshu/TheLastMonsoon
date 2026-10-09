"""Check temporary actual Godot skin/morph surfaces using Blender's native BVH."""
import sys,json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
folder=Path(sys.argv[sys.argv.index('--')+1]);summary={};references={}
sys.path.insert(0,str(Path(__file__).resolve().parent))
from purpose_cloth_volume import inside_surface,VolumeSurface
for path in sorted(folder.glob('*.json')):
 data=json.loads(path.read_text());vertices=[];faces=[]
 for body in data['body']:
  offset=len(vertices);vertices.extend(body['vertices']);ids=body['indices']
  # Godot winding is measured against its imported outward normals.
  reverse=body.get('winding_sign',1)<0
  faces.extend(tuple(offset+index for index in (reversed(ids[i:i+3]) if reverse else ids[i:i+3])) for i in range(0,len(ids),3))
 if not vertices or not faces:raise RuntimeError('Missing native body: '+str(path))
 tree=VolumeSurface.FromPolygons(vertices,faces,all_triangles=True)
 result=summary.setdefault(data['role'],{'samples':0,'violations':0,'worst_mm':0,'garments':{},'vertex_violations':0,'face_violations':0,'outside_nearest_normal_samples':0,'distortion_violations':0,'stretch_reference':'first actual standing pose, matching cloth solver rest'})
 for garment in data['garments']:
  points=[Vector(point) for point in garment['vertices']];ids=garment['indices']
  points += [sum((points[index] for index in ids[i:i+3]),Vector())/3 for i in range(0,len(ids),3)]
  cloth=result['garments'].setdefault(garment['name'],{'violations':0,'worst_mm':0,'failing_intervals':[],'stretched_edges':0,'maximum_edge_stretch':0,'envelope_violations':0,'stretch_examples':[],'bind_reference_stretched_edges':0})
  bind_rest=[Vector(point) for point in garment['rest_vertices']]
  rest=references.setdefault((data['role'],garment['name']),[point.copy() for point in points[:len(garment['vertices'])]])
  edges={tuple(sorted((ids[i+a],ids[i+b]))) for i in range(0,len(ids),3) for a,b in [(0,1),(1,2),(2,0)]}
  for a,b in edges:
   baseline=(rest[a]-rest[b]).length;posed=(points[a]-points[b]).length
   bind_length=(bind_rest[a]-bind_rest[b]).length
   if bind_length>.00001 and posed/bind_length>5 and posed>.05:cloth['bind_reference_stretched_edges']+=1
   if baseline<.00001:continue
   stretch=posed/baseline;cloth['maximum_edge_stretch']=max(cloth['maximum_edge_stretch'],stretch)
   if stretch>5 and posed>.05:
    cloth['stretched_edges']+=1;result['distortion_violations']+=1
    if len(cloth['stretch_examples'])<3:cloth['stretch_examples'].append({'sample':data['sample'],'edge':[a,b],'rest_m':baseline,'posed_m':posed,'a':list(points[a]),'b':list(points[b])})
  if garment['name'] in ['Clerk full length trousers','Opaque fitted underwear foundation']:
   for point in points[:len(garment['vertices'])]:
    if point.y>data['pelvis_y']+.22 or point.y<-.02 or abs(point.x)>.5:
     cloth['envelope_violations']+=1;result['distortion_violations']+=1
  for point_index,point in enumerate(points):
   near,normal,_,distance=tree.find_nearest(point)
   depth=(near-point).dot(normal)
   result['samples']+=1
   if distance>.002 and inside_surface(tree,point):
    depth=distance
    result['violations']+=1;cloth['violations']+=1
    interval=[int(key[0].rsplit(' ',1)[1]) for key in garment.get('active_keys',[])]
    if interval not in cloth['failing_intervals']:cloth['failing_intervals'].append(interval)
    result['vertex_violations' if point_index<len(garment['vertices']) else 'face_violations']+=1
    result['worst_mm']=max(result['worst_mm'],depth*1000);
    if depth*1000>cloth['worst_mm']:
     cloth['worst_mm']=depth*1000
     cloth['worst_pose']={'walking':data['walking'],'sample':data['sample'],'point':list(point),'active_keys':garment.get('active_keys',[])}
for role,result in summary.items():print('NATIVE_CONTACT',role,json.dumps(result),flush=True)
raise SystemExit(0 if summary and all(r['violations']==0 and r['distortion_violations']==0 for r in summary.values()) else 1)
