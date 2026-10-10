"""Refit existing shoulder cloth and interpolate its shirt weights; bodies unchanged."""
import bpy,sys
from pathlib import Path
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
role=sys.argv[sys.argv.index('--')+1]
source=ROOT/f'WorkingAssets/NPCs/households/{role}/{role}.blend'
bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.preferences.filepaths.save_version=0
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='REST'
bpy.context.view_layer.update()
shirt=bpy.data.objects['Fitted cotton upper base'];evaluated=shirt.evaluated_get(bpy.context.evaluated_depsgraph_get())
verts=[shirt.matrix_world@v.co for v in evaluated.data.vertices]
faces=[list(p.vertices) for p in evaluated.data.polygons];tree=BVHTree.FromPolygons(verts,faces)
cloth=bpy.data.objects['Bordered shoulder shawl']
for group in list(cloth.vertex_groups):cloth.vertex_groups.remove(group)
for group in shirt.vertex_groups:cloth.vertex_groups.new(name=group.name)
maximum=0.0
for vertex in cloth.data.vertices:
    original=cloth.matrix_world@vertex.co
    point,normal,face,distance=tree.find_nearest(original)
    if face is None:raise RuntimeError('shirt projection failed')
    # Retain the two baked cloth layers rather than collapsing them together.
    clearance=.010 if vertex.index < len(cloth.data.vertices)//2 else .0065
    at=point+normal*clearance
    vertex.co=cloth.matrix_world.inverted()@at
    nearest=faces[face]
    factors={i:1/max((verts[i]-point).length_squared,.000001) for i in nearest}
    total=sum(factors.values());weights={}
    for i,factor in factors.items():
        for assignment in evaluated.data.vertices[i].groups:
            weights[assignment.group]=weights.get(assignment.group,0)+assignment.weight*factor/total
    for group,weight in weights.items():
        if weight>.00001:cloth.vertex_groups[group].add([vertex.index],weight,'REPLACE')
    maximum=max(maximum,distance)
cloth['fit']='Shirt-surface projection; 6.5/10 mm inner/outer layers; interpolated shirt weights'
bpy.ops.wm.save_as_mainfile(filepath=str(source))
bpy.ops.export_scene.gltf(filepath=str(ROOT/f'characters/npcs/households/{role}.glb'),export_format='GLB',export_skins=True,export_animations=False,export_cameras=False,export_lights=False)
print('HOUSEHOLD_SHAWL_FIT',role,'vertices',len(cloth.data.vertices),'previous_max_gap_m',maximum,'inner_outer_rest_gap_m',[.0065,.010])
