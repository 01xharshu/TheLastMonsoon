"""Reference geometric fixtures for the cloth crossing audit."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import numpy as np
from river_triangle_contact import crosses
base=np.array([(0,0,0),(1,0,0),(0,1,0)],dtype=np.float64)
cross=np.array([(.2,.2,-.1),(.2,.4,.1),(.4,.2,.1)])
fixtures=[
 ('interior crossing',base,cross,True),
 ('parallel separated',base,base+np.array([0,0,.001]),False),
 ('coplanar overlap',base,base*.5+np.array([.1,.1,0]),False),
 ('shared folded edge',base,np.array([(0,0,0),(1,0,0),(.5,-.5,.2)]),False),
 ('finite disjoint edges',base,cross+np.array([4,4,0]),False),
 ('tiny facets at world position',base*.001+np.array([80,0,-4]),cross*.001+np.array([80,0,-4]),True),
 ('degenerate triangle',base,np.array([(0,0,0),(0,0,0),(0,0,0)]),False),
]
for name,a,b,expected in fixtures:
 actual=crosses(a,b)
 if actual!=expected:raise RuntimeError(name+': expected '+str(expected)+' got '+str(actual))
print('RIVER_LAYER_CHECKER PASS fixtures='+str(len(fixtures)),flush=True)
