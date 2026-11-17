"""Cut smoother, lower foundation armholes on a separate adult outfit study.

This edits cloth only, retaining opaque bust coverage and the existing lower
foundation. Skin weights and UVs interpolate at the new fabric edge.
"""
import argparse
from pathlib import Path
import sys
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--source',required=True,type=Path);p.add_argument('--output',required=True,type=Path)
args=p.parse_args(sys.argv[sys.argv.index('--')+1:]);source=args.source.resolve();output=args.output.resolve()
if not source.is_file() or output.exists() or source==output:raise ValueError('Requires separate new study output')
bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.preferences.filepaths.save_version=0
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='REST'
obj=bpy.data.objects['Opaque fitted bra and thong foundation'];data=obj.data
bpy.context.view_layer.update();evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh();mesh.calc_loop_triangles()
if len(mesh.vertices)!=len(data.vertices):raise RuntimeError('Foundation evaluation must preserve vertex correspondence')
uv=mesh.uv_layers.active

def smooth(a,b,value):
    t=max(0.,min(1.,(value-a)/(b-a)));return t*t*(3-2*t)
def signed(point):
    world=obj.matrix_world@point
    top=1.065+.12*smooth(.04,.09,abs(world.y))+.14*(1-smooth(.105,.145,abs(world.x)))
    return top-world.z

def interpolate(a,b,t):
    groups=set(a['weights'])|set(b['weights'])
    return dict(co=a['co'].lerp(b['co'],t),uv=a['uv'].lerp(b['uv'],t),
                weights={g:a['weights'].get(g,0)*(1-t)+b['weights'].get(g,0)*t for g in groups})
vertices=[];faces=[];materials=[];lookup={};removed=0
for triangle in mesh.loop_triangles:
    polygon=[]
    for index,loop in zip(triangle.vertices,triangle.loops):
        polygon.append(dict(co=mesh.vertices[index].co.copy(),uv=uv.data[loop].uv.copy() if uv else Vector((0.,0.)),
                            weights={g.group:g.weight for g in data.vertices[index].groups}))
    clipped=[]
    for current,following in zip(polygon,polygon[1:]+polygon[:1]):
        a,b=signed(current['co']),signed(following['co'])
        if a>=0:clipped.append(current)
        if (a>=0)!=(b>=0):clipped.append(interpolate(current,following,a/(a-b)))
    if len(clipped)<3:removed+=1;continue
    indices=[]
    for point in clipped:
        stamp=tuple(round(v,7) for v in point['co'])+tuple(round(v,7) for v in point['uv'])
        if stamp not in lookup:lookup[stamp]=len(vertices);vertices.append(point)
        indices.append(lookup[stamp])
    for index in range(1,len(indices)-1):
        face=(indices[0],indices[index],indices[index+1])
        if len(set(face))==3:faces.append(face);materials.append(triangle.material_index)
if not removed or len(faces)<len(mesh.loop_triangles)*.7:raise RuntimeError('Armhole clipping removed unexpected foundation coverage')
old_materials=list(data.materials);group_names=[group.name for group in obj.vertex_groups];evaluated.to_mesh_clear()
obj.shape_key_clear();result=bpy.data.meshes.new('Smooth adult foundation armholes')
result.from_pydata([v['co'] for v in vertices],[],faces);result.update()
for material in old_materials:result.materials.append(material)
obj.data=result
obj.vertex_groups.clear()
for name in group_names:obj.vertex_groups.new(name=name)
for index,point in enumerate(vertices):
    for group,weight in point['weights'].items():
        if weight>.000001:obj.vertex_groups[group].add([index],weight,'REPLACE')
layer=result.uv_layers.new(name='UVMap')
for polygon,material in zip(result.polygons,materials):
    polygon.use_smooth=True;polygon.material_index=material
    for loop in polygon.loop_indices:layer.data[loop].uv=vertices[result.loops[loop].vertex_index]['uv']
obj['armhole_construction']='Smooth lowered side armholes; opaque bust and lower foundation retained'
output.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(output))
print('FOUNDATION_ARMHOLES',len(vertices),len(faces),'removed_triangles',removed,'unapproved',output,flush=True)
