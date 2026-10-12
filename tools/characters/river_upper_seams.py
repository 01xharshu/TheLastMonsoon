"""Construction constraints for the existing cotton waist and sleeve openings.

Only cloth coordinates change. The complete MPFB body and original detailed
garments remain untouched. Boundary loops retain their topology and skin weights.
"""
from collections import Counter,defaultdict
import numpy as np

def seam_specs(obj,rig):
    obj.data.calc_loop_triangles();counts=Counter();graph=defaultdict(set)
    for face in obj.data.loop_triangles:
        for i in range(3):counts[tuple(sorted((face.vertices[i],face.vertices[(i+1)%3])))]+=1
    for (a,b),count in counts.items():
        if count>2:raise RuntimeError('Nonmanifold upper cloth cannot receive seam constraints')
        if count==1:graph[a].add(b);graph[b].add(a)
    if any(len(row)!=2 for row in graph.values()):raise RuntimeError('Branched cloth opening')
    basis=obj.data.shape_keys.key_blocks['Basis'];pending=set(graph);specs=[]
    while pending:
        start=min(pending);ids=[start];previous=None;current=start
        while True:
            choices=sorted(graph[current]-({previous} if previous is not None else set()))
            following=choices[0]
            if following==start:break
            if following in ids:raise RuntimeError('Invalid cloth boundary cycle')
            ids.append(following);previous,current=current,following
        pending.difference_update(ids)
        points=np.asarray([basis.data[i].co[:] for i in ids],dtype=np.float32);centre=points.mean(axis=0)
        if abs(float(centre[0]))>.2:
            world=obj.matrix_world@basis.data[ids[0]].co
            bone_name=min(['upperarm_l','upperarm_r'],key=lambda name:(rig.matrix_world@rig.data.bones[name].head_local-world).length)
        elif float(centre[2])<.95:bone_name='spine_01'
        else:continue # Keep the established neckline construction.
        frame=rig.matrix_world@rig.data.bones[bone_name].matrix_local
        local=np.asarray([(frame.inverted_safe()@obj.matrix_world@basis.data[i].co)[:] for i in ids],dtype=np.float32)
        cx=(float(local[:,0].min())+float(local[:,0].max()))*.5
        cz=(float(local[:,2].min())+float(local[:,2].max()))*.5
        rx=max(.025,(float(local[:,0].max())-float(local[:,0].min()))*.5)
        rz=max(.025,(float(local[:,2].max())-float(local[:,2].min()))*.5)
        angle=np.arctan2((local[:,2]-cz)/rz,(local[:,0]-cx)/rx)
        area=np.sum((local[:,0]-cx)*np.roll(local[:,2]-cz,-1)-np.roll(local[:,0]-cx,-1)*(local[:,2]-cz))
        direction=1.0 if area>0 else -1.0
        theta=angle[0]+direction*np.arange(len(ids))*2*np.pi/len(ids)
        target=np.column_stack((cx+rx*np.cos(theta),np.full(len(ids),local[:,1].mean()),cz+rz*np.sin(theta),np.ones(len(ids)))).astype(np.float32)
        specs.append({'bone':bone_name,'ids':ids,'local_targets':target})
    if len(specs)!=3:raise RuntimeError('Expected two sleeve cuffs and one waist seam')
    return specs

def apply_seams(coordinates,specs,frames,neighbors):
    worst=0.0
    for spec,matrices in zip(specs,frames):
        ids=spec['ids'];targets=np.einsum('kij,vj->kvi',matrices,spec['local_targets'])[:,:,:3]
        delta=np.zeros_like(coordinates);delta[:,ids,:]=targets-coordinates[:,ids,:]
        worst=max(worst,float(np.linalg.norm(delta[:,ids,:],axis=2).max()))
        visited=set(ids);frontier=set(ids);last_weight=1.0
        # Spread seam corrections into adjacent fabric instead of creating
        # a hard ring connected to stretched, pointed triangles.
        for weight in [.65,.3,.1]:
            next_frontier={v for i in frontier for v in neighbors[i] if v not in visited}
            for vertex in sorted(next_frontier):
                contributors=sorted(neighbors[vertex]&visited)
                delta[:,vertex,:]=delta[:,contributors,:].mean(axis=1)*(weight/last_weight)
            visited.update(next_frontier);frontier=next_frontier;last_weight=weight
        coordinates+=delta
    print('RIVER_UPPER_SEAMS openings',len(specs),'boundary_vertices',sum(len(spec['ids']) for spec in specs),'max_world_shift_m',worst,flush=True)
