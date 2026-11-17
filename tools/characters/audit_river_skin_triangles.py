"""Detect actual lower-wrap/complete-body triangle crossings in saved test poses."""
import json,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0,str(Path(__file__).resolve().parent))
from river_triangle_contact import crosses,CONTACT_EPS_M
folder=Path(sys.argv[sys.argv.index('--')+1]);counts={};total=0
files=sorted(folder.glob('river_*.json'))
if not files:raise RuntimeError('No skin surfaces to audit')
def data(entry):
 points=[Vector(p) for p in entry['vertices']];ids=entry['indices'];faces=[tuple(ids[i:i+3]) for i in range(0,len(ids),3)]
 return points,faces,BVHTree.FromPolygons(points,faces,all_triangles=True)
for file in files:
 pose=json.loads(file.read_text());body=pose['body'];garments=pose['garments']
 if not body:raise RuntimeError('Complete body missing in '+str(file))
 for skin in body:
  a,af,at=data(skin)
  for cloth in [item for item in garments if item['name'] in ['Wrapped sari lower drape','Sari lower border']]:
   b,bf,bt=data(cloth)
   for ai,bi in at.overlap(bt):
    if crosses([a[i] for i in af[ai]],[b[i] for i in bf[bi]]):
     total+=1;label=str(pose['label']);counts[label]=counts.get(label,0)+1
print('RIVER_SKIN_TRIANGLES',json.dumps({'poses':len(files),'crossings':total,'by_pose':counts,'contact_tolerance_m':CONTACT_EPS_M}),flush=True)
raise SystemExit(1 if total else 0)
