"""Clothing-only cuff cutting, preserving the original human body."""
import bmesh

def trim_work_sleeves(obj,prefixes,limit):
    """Finish a work-shirt cuff on the donor cloth's deform-weight contour."""
    indices={g.index for g in obj.vertex_groups if g.name.startswith(prefixes)}
    bm=bmesh.new();bm.from_mesh(obj.data);deform=bm.verts.layers.deform.verify()
    def weight(vertex):return sum(vertex[deform].get(i,0) for i in indices)
    boundary=set()
    for edge in list(bm.edges):
        a,b=edge.verts;wa,wb=weight(a),weight(b)
        if (wa-limit)*(wb-limit)>=0:continue
        t=(limit-wa)/(wb-wa);ga=dict(a[deform]);gb=dict(b[deform])
        _,vertex=bmesh.utils.edge_split(edge,a,t)
        for group in ga.keys()|gb.keys():vertex[deform][group]=(1-t)*ga.get(group,0)+t*gb.get(group,0)
        boundary.add(vertex)
    for face in list(bm.faces):
        cuts=[v for v in face.verts if v in boundary]
        if len(cuts)==2 and len(face.verts)>3:bmesh.utils.face_split(face,cuts[0],cuts[1])
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if sum(weight(v) for v in f.verts)/len(f.verts)>limit+1e-6],context='FACES')
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
    bm.to_mesh(obj.data);bm.free();obj.data.update()

