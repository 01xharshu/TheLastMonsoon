"""Conservative sewn-edge finish for the fitted cotton derivative, not the body."""
from collections import Counter,defaultdict
from mathutils import Vector
import json

def finish_upper(obj):
    if obj.get("cotton_finish_metrics"):
        return json.loads(obj["cotton_finish_metrics"])
    edges=Counter()
    for face in obj.data.polygons:
        ids=list(face.vertices)
        for a,b in zip(ids,ids[1:]+ids[:1]):edges[tuple(sorted((a,b)))]+=1
    neighbors=defaultdict(set)
    for (a,b),count in edges.items():
        if count==1:neighbors[a].add(b);neighbors[b].add(a)
    boundary={i:tuple(v) for i,v in neighbors.items() if len(v)==2}
    maximum=0.0
    for key in obj.data.shape_keys.key_blocks:
        original={i:key.data[i].co.copy() for i in boundary}
        for sweep in range(2):
            before={i:key.data[i].co.copy() for i in boundary}
            for i,(a,b) in boundary.items():
                target=before[i]*.5+(before.get(a,key.data[a].co)+before.get(b,key.data[b].co))*.25
                change=target-original[i]
                if change.length>.006:target=original[i]+change.normalized()*.006
                key.data[i].co=target
        if key.name=='Basis':maximum=max(((key.data[i].co-original[i]).length for i in boundary),default=0.0)
    # A continuous pattern coordinate avoids face-by-face jagged colour steps.
    colors=obj.data.color_attributes.get('Cotton region')
    if colors is None:raise RuntimeError('Missing authored cotton region attribute')
    basis=obj.data.shape_keys.key_blocks['Basis']
    for loop in obj.data.loops:
        p=basis.data[loop.vertex_index].co
        centre=.14-(p.z-.85)*.29/.39
        distance=min(.14-abs(p.x-centre),.005-p.y)
        colors.data[loop.index].color=(max(0.0,min(1.0,.5+distance/.08)),0,0,1)
    for vertex,point in zip(obj.data.vertices,basis.data):vertex.co=point.co
    obj.data.update()
    obj['cotton_sewn_edge_finish']='Two conservative boundary passes, max6mm; complete body unchanged'
    metrics={'boundary_vertices':len(boundary),'maximum_basis_shift_m':maximum,'body_changed':False}
    obj['cotton_finish_metrics']=json.dumps(metrics)
    return metrics

def integral_border(lower, guide):
    lower.data.update()
    orientation=sum(face.normal.dot(Vector((face.center.x,face.center.y,0))) for face in lower.data.polygons)
    flipped=orientation<0
    if flipped:
        lower.data.flip_normals();lower.data.update()
    lower['outward_fabric_winding']=True
    # A woven sari border belongs to the same cloth. Retain the editable guide
    # but do not export a second independently deforming sheet through the hem.
    guide['activity_source_only']=True
    guide['construction_guide']='Woven border rendered on lower-wrap UVs; editable guide only'
    guide.hide_render=True;guide.hide_set(True)
    lower['integral_woven_border']=True
    lower['border_uv_fraction']=.035
    return {'style':'integral woven UV band','width_fraction':.035,'editable_guide_retained':True,'outward_winding':True,'winding_corrected':flipped}
