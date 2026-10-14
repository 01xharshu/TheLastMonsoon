"""Measure actual posed foundation clearance; generated input stays temporary."""
import sys,json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
folder=Path(sys.argv[sys.argv.index('--')+1])
for path in sorted(folder.glob('river_*.json')):
    data=json.loads(path.read_text());points=[];faces=[]
    for entry in data['body']:
        offset=len(points);points.extend(Vector(point) for point in entry['vertices'])
        ids=entry['indices'];faces.extend(tuple(offset+index for index in ids[j:j+3]) for j in range(0,len(ids),3))
    tree=BVHTree.FromPolygons(points,faces,all_triangles=True)
    entry=next(entry for entry in data['garments'] if entry['name']=='Opaque fitted bra and thong foundation')
    upper=set(entry.get('upper_foundation_indices',[]))
    for region,selected in [('bra',upper),('lower',set(range(len(entry['vertices'])))-upper)]:
        distances=sorted(tree.find_nearest(Vector(entry['vertices'][index]))[3] for index in selected)
        if not distances:raise RuntimeError('Missing foundation region '+region)
        print('RIVER_FOUNDATION_FIT',json.dumps({'pose':data['label'],'region':region,'vertices':len(distances),
              'median_m':distances[len(distances)//2],'p95_m':distances[int((len(distances)-1)*.95)],'maximum_m':max(distances)}),flush=True)
