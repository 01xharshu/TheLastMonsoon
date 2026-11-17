"""Cylindrical fabric UVs for authored cloth; geometry and skin stay unchanged."""
import math
def ensure_fabric_uvs(obj):
    mesh=obj.data
    if mesh.uv_layers.active:return False
    uv=mesh.uv_layers.new(name='Fabric UV')
    bottom=min(v.co.z for v in mesh.vertices);height=max(v.co.z for v in mesh.vertices)-bottom
    for face in mesh.polygons:
        values=[]
        for loop in face.loop_indices:
            p=mesh.vertices[mesh.loops[loop].vertex_index].co
            values.append([.5+math.atan2(p.x,-p.y)/math.tau,(p.z-bottom)/max(.001,height)])
        if max(v[0] for v in values)-min(v[0] for v in values)>.5:
            for value in values:
                if value[0]>.5:value[0]-=1
        for loop,value in zip(face.loop_indices,values):uv.data[loop].uv=value
    return True
