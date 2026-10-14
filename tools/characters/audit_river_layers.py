"""Check actual deformed foundation/blouse/pallu triangle crossings; no retained report."""
import json,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
folder=Path(sys.argv[sys.argv.index('--')+1]);checked=0;crossings=[];relationships={}
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
    for first,second,relationship in pairs:
        av,af,at=triangles(first)
        bv,bf,bt=triangles(second)
        for ai,bi in at.overlap(bt):
            checked+=1
            if crosses([av[v] for v in af[ai]],[bv[v] for v in bf[bi]]):
                relationships[relationship]=relationships.get(relationship,0)+1
                crossings.append({'pose':data['label'],'relationship':relationship,'first_face':ai,'second_face':bi,**({'first_points':[list(av[v]) for v in af[ai]],'second_points':[list(bv[v]) for v in bf[bi]]} if '--inspect' in sys.argv and len(crossings)<3 else {})})
print('RIVER_LAYER_CONTACT',json.dumps({'contact_tolerance_m':CONTACT_EPS_M,'poses':len(list(folder.glob('*.json'))),'candidate_pairs_checked':checked,'crossings':len(crossings),'by_relationship':relationships,'first_crossings':crossings[:8]}))
raise SystemExit(1 if crossings else 0)
