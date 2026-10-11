"""Double-precision finite triangle crossings with a 10 micrometre contact tolerance."""
import numpy as np
CONTACT_EPS_M=.00001

def crosses(a,b):
    # Narrow-phase arithmetic must be double precision: millimetre-scale
    # cloth slivers at metre-scale world positions lose barycentric precision
    # in mathutils Vector (float32), creating false shared-edge hits.
    a=np.asarray(a,dtype=np.float64);b=np.asarray(b,dtype=np.float64)
    for first,second in [(a,b),(b,a)]:
        e1=second[1]-second[0];e2=second[2]-second[0]
        normal=np.cross(e1,e2);length=np.linalg.norm(normal)
        if length<1e-15:continue
        distances=(first-second[0])@(normal/length)
        for i in range(3):
            left=distances[i];right=distances[(i+1)%3]
            if not ((left<-CONTACT_EPS_M and right>CONTACT_EPS_M) or (right<-CONTACT_EPS_M and left>CONTACT_EPS_M)):continue
            start=first[i];direction=first[(i+1)%3]-start
            h=np.cross(direction,e2);det=e1@h
            if abs(det)<1e-15:continue
            offset=start-second[0];u=(offset@h)/det
            if u<0 or u>1:continue
            q=np.cross(offset,e1);v=(direction@q)/det
            if v<0 or u+v>1:continue
            t=(e2@q)/det
            if not 0<t<1:continue
            hit=start+direction*t
            # Apply a world-space boundary tolerance, not a dimensionless
            # barycentric epsilon that collapses on tiny garment facets.
            interior=True
            for j in range(3):
                edge=second[(j+1)%3]-second[j];edge_length=np.linalg.norm(edge)
                distance=np.linalg.norm(np.cross(hit-second[j],edge))/max(edge_length,1e-15)
                if distance<=CONTACT_EPS_M:interior=False;break
            if interior:return True
    return False
