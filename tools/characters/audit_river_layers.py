"""Check actual deformed clothing-layer triangle crossings; no retained report."""
import json,sys
from collections import Counter,defaultdict
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
folder=Path(sys.argv[sys.argv.index('--')+1]);checked=0;crossings=[];relationships={};pose_counts=defaultdict(Counter);inspect_first={}
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
    pairs=[(first,second,'blouse/pallu') for first in upper for second in pallu]
    foundation=[g for g in garments if g['name']=='Opaque fitted bra and thong foundation']
    if not foundation:raise RuntimeError('Opaque foundation missing from native surfaces')
    pairs.extend((first,second,'foundation/'+('pallu' if second in pallu else 'blouse')) for first in foundation for second in upper+pallu)
    lower=[g for g in garments if g['name'] in ['Wrapped sari lower drape','Sari lower border']]
    if len(lower)!=2:raise RuntimeError('Complete lower wrap and border missing from native surfaces')
    pairs.extend((first,second,first['name']+'/'+second['name']) for first in lower for second in foundation+upper+pallu)
    pairs.append((lower[0],lower[1],'lower wrap/border'))
    for first,second,relationship in pairs:
        av,af,at=triangles(first)
        bv,bf,bt=triangles(second)
        for ai,bi in at.overlap(bt):
            checked+=1
            if crosses([av[v] for v in af[ai]],[bv[v] for v in bf[bi]]):
                relationships[relationship]=relationships.get(relationship,0)+1
                pose_counts[relationship][data['label']]+=1
                if '--inspect' in sys.argv and relationship not in inspect_first:inspect_first[relationship]={'pose':data['label'],'first_points':[list(av[v]) for v in af[ai]],'second_points':[list(bv[v]) for v in bf[bi]]}
                crossings.append({'pose':data['label'],'pose_time':data.get('pose_time'),'relationship':relationship,'first_face':ai,'second_face':bi,**({'first_points':[list(av[v]) for v in af[ai]],'second_points':[list(bv[v]) for v in bf[bi]]} if '--inspect' in sys.argv and len(crossings)<3 else {})})
print('RIVER_LAYER_CONTACT',json.dumps({'contact_tolerance_m':CONTACT_EPS_M,'poses':len(list(folder.glob('*.json'))),'candidate_pairs_checked':checked,'crossings':len(crossings),'by_relationship':relationships,'by_pose':{k:v.most_common(8) for k,v in pose_counts.items()},'first_crossings':crossings[:8],**({'inspect_first':inspect_first} if '--inspect' in sys.argv else {})}))
raise SystemExit(1 if crossings else 0)
