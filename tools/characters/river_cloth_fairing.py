"""Fair runtime cloth coordinates without changing retained anatomy or garments.

Taubin's alternating Laplacian passes reduce the inherited skin-detail folds
without the progressive shrinkage of ordinary repeated averaging. Every keyed
pose uses the same adjacency, so interpolation stays continuous.
"""
import numpy as np

def fair_upper(obj, rounds=6, posed=None, sew=False):
    if not obj.get('river_composite',False) or obj.get('river_source_only',False):
        raise RuntimeError('Fairing requires the runtime composite upper garment')
    keys=list(obj.data.shape_keys.key_blocks)
    size=len(obj.data.vertices)
    neighbors=[set() for _ in range(size)]
    for edge in obj.data.edges:
        a,b=edge.vertices;neighbors[a].add(b);neighbors[b].add(a)
    coordinates=np.empty((len(keys),size,3),dtype=np.float32)
    for index,key in enumerate(keys):key.data.foreach_get('co',coordinates[index].reshape(-1))
    original=coordinates.copy()
    inverses=None
    if posed is not None:
        # Corrective coordinates counteract each vertex's skin transform.
        # Smooth the rendered pose, not that compensation in bind space.
        from mathutils import Matrix
        from river_surface_binding import inverse_skin
        from river_cloth_correctives import apply_river_pose
        rig,data,conversion,corrections=posed
        poses={pose.get('key','River cloth %03d'%i):pose for i,pose in enumerate(data['poses'])}
        if sew:
            from river_upper_seams import seam_specs,apply_seams
            specs=seam_specs(obj,rig)
            seam_frames=[np.empty((len(keys),4,4),dtype=np.float32) for _ in specs]
        inverses=np.empty((len(keys),size,4,4),dtype=np.float32)
        for index,key in enumerate(keys):
            if key.name=='Basis':
                for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
                import bpy
                bpy.context.view_layer.update()
            else:
                if key.name not in poses:raise RuntimeError('Missing authored pose for cloth key '+key.name)
                apply_river_pose(rig,poses[key.name]['bones'],conversion,corrections)
            matrices=inverse_skin(rig,obj)
            if sew:
                for spec,frames in zip(specs,seam_frames):frames[index]=np.asarray(rig.matrix_world@rig.pose.bones[spec['bone']].matrix,dtype=np.float32)
            for vertex,matrix in enumerate(matrices):
                inverses[index,vertex]=np.asarray(matrix,dtype=np.float32)
                point=np.append(coordinates[index,vertex],1.0)
                coordinates[index,vertex]=(np.asarray(matrix.inverted_safe(),dtype=np.float32)@point)[:3]
            if index%48==0:print('RIVER_UPPER_FAIRING_POSE',index,'of',len(keys),flush=True)
    for _ in range(rounds):
        for strength in [.5,-.53]:
            mean=coordinates.copy()
            for vertex,adjacent in enumerate(neighbors):
                if adjacent:mean[:,vertex,:]=coordinates[:,list(adjacent),:].mean(axis=1)
            coordinates+=strength*(mean-coordinates)
    if sew:
        if posed is None:raise RuntimeError('Seams require authored pose frames')
        apply_seams(coordinates,specs,seam_frames,neighbors)
        obj['river_upper_seams']='Pose-conforming sleeve cuffs and waist; unchanged topology/skin weights'
    if inverses is not None:
        homogeneous=np.concatenate((coordinates,np.ones((*coordinates.shape[:2],1),dtype=np.float32)),axis=2)
        coordinates=np.einsum('kvij,kvj->kvi',inverses,homogeneous)[:,:,:3]
        for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
    for index,key in enumerate(keys):key.data.foreach_set('co',coordinates[index].reshape(-1))
    obj.data.update()
    shift=float(np.linalg.norm(coordinates-original,axis=2).max())
    obj['river_fairing_space']='posed' if posed is not None else 'bind'
    obj['river_fairing_rounds']=int(obj.get('river_fairing_rounds',0))+rounds
    print('RIVER_UPPER_FAIRING space',obj['river_fairing_space'],'keys',len(keys),'vertices',size,'rounds',rounds,'max_shift_m',shift,flush=True)
    return shift
