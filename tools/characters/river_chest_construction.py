"""Replace folded skin-detail cloth topology with a connected front fabric patch.

The complete human body, foundation and retained garments are untouched. Keep
the seam-fitted candidate as an editable reference until replacement validation.
"""
import bpy,bmesh,numpy as np

def remesh_chest(obj,subdivide_only=False,foundation=False):
    if foundation:
        if not subdivide_only or obj.name!='Opaque fitted bra and thong foundation':raise RuntimeError('Foundation subdivision requires the retained opaque foundation')
    elif not obj.get('river_composite',False):raise RuntimeError('Runtime composite garment required')
    reference_name='Retained coarse river foundation' if foundation else 'Retained seam-fitted river upper'
    if bpy.data.objects.get(reference_name) is None:
        reference=obj.copy();reference.data=obj.data.copy();reference.name=reference_name
        bpy.context.collection.objects.link(reference)
        reference['river_source_only']=True;reference.hide_render=True;reference.hide_set(True)
    count=len(obj.data.shape_keys.key_blocks)
    bounds=[]
    for key in obj.data.shape_keys.key_blocks:
        coordinates=np.empty(len(key.data)*3,dtype=np.float32);key.data.foreach_get('co',coordinates)
        coordinates=coordinates.reshape(-1,3);bounds.append((coordinates.min(axis=0),coordinates.max(axis=0)))
    bm=bmesh.new()
    try:
        bm.from_mesh(obj.data)
        basis=bm.verts.layers.shape.get('Basis')
        if basis is None:raise RuntimeError('Cloth basis shape layer missing')
        for vertex in bm.verts:vertex.co=vertex[basis].copy()
        bm.normal_update()
        selected=list(bm.faces) if subdivide_only else [face for face in bm.faces if all(.94<vertex.co.z<1.22 and abs(vertex.co.x)<.215 and vertex.co.y<-.025 for vertex in face.verts)]
        if len(selected)<40:raise RuntimeError('Cloth construction selection too small')
        if subdivide_only:
            edges=list(bm.edges)
        else:
            result=bmesh.ops.dissolve_faces(bm,faces=selected,use_verts=True)
            regions=[face for face in result['region'] if isinstance(face,bmesh.types.BMFace) and face.is_valid]
            if not regions:raise RuntimeError('Front fabric patch missing after dissolution')
            result=bmesh.ops.triangulate(bm,faces=regions,quad_method='BEAUTY',ngon_method='BEAUTY')
            edges=list({edge for face in result['faces'] for edge in face.edges})
        bmesh.ops.subdivide_edges(bm,edges=edges,cuts=1 if subdivide_only else 2,use_grid_fill=True)
        bmesh.ops.triangulate(bm,faces=list(bm.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
        bm.normal_update();bm.to_mesh(obj.data);obj.data.update()
    finally:bm.free()
    if len(obj.data.shape_keys.key_blocks)!=count:raise RuntimeError('Cloth corrective shapes lost during construction')
    if any(len(key.data)!=len(obj.data.vertices) for key in obj.data.shape_keys.key_blocks):raise RuntimeError('Cloth shape topology mismatch')
    rig=next(modifier.object for modifier in obj.modifiers if modifier.type=='ARMATURE')
    for vertex in obj.data.vertices:
        weight=sum(group.weight for group in vertex.groups if obj.vertex_groups[group.group].name in rig.data.bones)
        if abs(weight-1.0)>.005:raise RuntimeError('Cloth skin weights not preserved at vertex '+str(vertex.index))
    for key,(low,high) in zip(obj.data.shape_keys.key_blocks,bounds):
        coordinates=np.empty(len(key.data)*3,dtype=np.float32);key.data.foreach_get('co',coordinates)
        coordinates=coordinates.reshape(-1,3)
        if not np.isfinite(coordinates).all() or (coordinates.min(axis=0)<low-.00001).any() or (coordinates.max(axis=0)>high+.00001).any():
            raise RuntimeError('Cloth shape interpolation left its original bounds: '+key.name)
    basis=obj.data.shape_keys.key_blocks['Basis']
    mask=obj.data.color_attributes.get('River panel mask')
    if mask is None and not foundation:raise RuntimeError('Cotton-region mask missing')
    for face in obj.data.polygons:
        p=sum((basis.data[i].co for i in face.vertices),basis.data[face.vertices[0]].co*0)/len(face.vertices)
        panel=.84<p.z<1.245 and p.y<.005 and abs(p.x-(.14-(p.z-.85)*.29/.39))<.105
        if not foundation:
            for index in face.loop_indices:mask.data[index].color=(1,0,0,1) if panel else (0,0,0,1)
        face.use_smooth=True
    obj['river_chest_construction']=('Subdivided existing cloth topology' if subdivide_only else 'Connected fabric patch')+'; original detailed and seam-fitted garments retained'
    print('RIVER_CHEST_CONSTRUCTION selected_faces',len(selected),'vertices',len(obj.data.vertices),'triangles',len(obj.data.polygons),'keys',count,flush=True)
