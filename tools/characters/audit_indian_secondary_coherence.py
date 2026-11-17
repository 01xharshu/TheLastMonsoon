"""Compare actual body/foundation displacement with the same pose, springs off.

Consumes disposable native snapshots; creates no report or retained output.
"""
import json
from pathlib import Path
import sys
from mathutils import Vector
from mathutils.kdtree import KDTree
folder=Path(sys.argv[sys.argv.index('--')+1])
pairs=0;maximum=0.;body_peak=0.;checked=0
for path in sorted(folder.glob('realtime_*.json')):
    data=json.loads(path.read_text());body=[];delta=[]
    for skin in data['body']:
        baseline=skin.get('neutral_vertices')
        if not baseline:continue
        body.extend(Vector(point) for point in baseline)
        delta.extend(Vector(current)-Vector(neutral) for current,neutral in zip(skin['vertices'],baseline))
    if not body:continue
    tree=KDTree(len(body))
    for index,point in enumerate(body):tree.insert(point,index)
    tree.balance()
    for cloth in data['garments']:
        if cloth['name']!='Opaque fitted bra and thong foundation':continue
        for current,neutral in zip(cloth['vertices'],cloth.get('neutral_vertices',[])):
            neutral=Vector(neutral);nearest=tree.find_n(neutral,3)
            if nearest[0][2]>.03:continue
            factors=[1./max(distance,.001)**2 for _,_,distance in nearest];total=sum(factors)
            expected=sum((delta[index]*factor for (_,index,_),factor in zip(nearest,factors)),Vector())/total
            actual=Vector(current)-neutral
            if max(expected.length,actual.length)<.00001:continue
            pairs+=1;maximum=max(maximum,(actual-expected).length);body_peak=max(body_peak,expected.length)
    checked+=1
print('INDIAN_SECONDARY_COHERENCE',json.dumps(dict(samples=checked,moving_pairs=pairs,
      max_body_foundation_difference_mm=maximum*1000,body_peak_mm=body_peak*1000,
      passed=checked>=4 and pairs>100 and maximum<=.001)),flush=True)
if checked<4 or pairs<=100 or maximum>.001:raise RuntimeError('Actual body/foundation secondary displacement is not coherent')
