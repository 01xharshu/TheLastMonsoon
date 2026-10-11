"""Check actual deformed pallu/blouse triangle crossings; no retained report."""
import json,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
folder=Path(sys.argv[sys.argv.index('--')+1]);checked=0;crossings=[]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from river_triangle_contact import crosses,CONTACT_EPS_M
def triangles(entry):
    points=[Vector(p) for p in entry['vertices']];ids=entry['indices']
    faces=[tuple(ids[i:i+3]) for i in range(0,len(ids),3)]
    return points,faces,BVHTree.FromPolygons(points,faces,all_triangles=True)
for file in sorted(folder.glob('*.json')):
    data=json.loads(file.read_text());garments=data['garments']
    upper=[g for g in garments if 'Fitted cotton upper' in g['name']]
    pallu=[g for g in garments if 'pallu' in g['name'].lower()]
    if not upper or not pallu:raise RuntimeError('Missing pallu or blouse in actual native surfaces')
    for first in upper:
        av,af,at=triangles(first)
        for second in pallu:
            bv,bf,bt=triangles(second)
            for ai,bi in at.overlap(bt):
                checked+=1
                if crosses([av[v] for v in af[ai]],[bv[v] for v in bf[bi]]):
                    crossings.append({'pose':data['label'],'blouse_face':ai,'pallu_face':bi,**({'blouse_points':[list(av[v]) for v in af[ai]],'pallu_points':[list(bv[v]) for v in bf[bi]]} if '--inspect' in sys.argv and len(crossings)<3 else {})})
print('RIVER_LAYER_CONTACT',json.dumps({'contact_tolerance_m':CONTACT_EPS_M,'poses':len(list(folder.glob('*.json'))),'candidate_pairs_checked':checked,'crossings':len(crossings),'first_crossings':crossings[:8]}))
raise SystemExit(1 if crossings else 0)
