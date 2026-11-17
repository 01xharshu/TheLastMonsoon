"""Audit disjoint torso/leg skin triangles in disposable native river snapshots."""
import sys,json
from pathlib import Path
from mathutils.bvhtree import BVHTree
sys.path.insert(0,str(Path(__file__).resolve().parent))
from river_triangle_contact import crosses
folder=Path(sys.argv[sys.argv.index('--')+1]);passed=True;total=0;crossings=0;minimum=float('inf');summary='--summary' in sys.argv
for path in sorted(folder.glob('river_*.json')):
    data=json.loads(path.read_text());hits=0;regions=0
    for entry in data['body']:
        vertices=entry['vertices'];upper=entry.get('upper_torso_indices',[]);lower=entry.get('lower_body_indices',[])
        if not upper or not lower:continue
        regions+=1
        upper=[tuple(upper[i:i+3]) for i in range(0,len(upper),3)]
        lower=[tuple(lower[i:i+3]) for i in range(0,len(lower),3)]
        a=BVHTree.FromPolygons(vertices,upper,all_triangles=True);b=BVHTree.FromPolygons(vertices,lower,all_triangles=True)
        for i,j in a.overlap(b):
            if crosses([vertices[k] for k in upper[i]],[vertices[k] for k in lower[j]]):hits+=1
    if not regions:raise RuntimeError('Missing native torso/leg region metadata')
    clearance=float(data['minimum_knee_clearance_m']);valid=hits==0 and clearance>=-.002
    total+=1;passed=passed and valid;crossings+=hits;minimum=min(minimum,clearance)
    if not summary or not valid:print('RIVER_BODY_CONTACT',json.dumps({'pose':data['label'],'torso_leg_crossings':hits,'knee_clearance_m':clearance,'passed':valid}),flush=True)
if summary:print('RIVER_BODY_CONTACT',json.dumps({'poses':total,'torso_leg_crossings':crossings,'minimum_knee_clearance_m':minimum,'passed':passed and total>0}),flush=True)
raise SystemExit(0 if passed and total else 1)
