"""Fit river garments to sampled runtime poses of the unchanged MPFB body."""
import bpy, json
from mathutils import Matrix, Vector
from river_coherent_cloth import fit_key
from river_surface_binding import apply_surface,wrap_surface
from purpose_cloth_volume import VolumeSurface

def apply_river_pose(rig, bones, conversion, corrections):
    """Set local bases from explicit parent targets, independent of stale pose caches."""
    inverse=conversion.inverted()
    targets={name:conversion@Matrix(matrix)@inverse@corrections[name] for name,matrix in bones.items() if name in corrections}
    for bone in rig.pose.bones:
        if bone.name not in targets:continue
        arguments={}
        if bone.parent is not None:
            arguments={'parent_matrix':targets[bone.parent.name], 'parent_matrix_local':bone.parent.bone.matrix_local}
        bone.matrix_basis=bone.bone.convert_local_to_pose(targets[bone.name],bone.bone.matrix_local,invert=True,**arguments)
    bpy.context.view_layer.update()
    error=max(max(abs(value) for row in (bone.matrix-targets[bone.name]) for value in row) for bone in rig.pose.bones if bone.name in targets)
    if error>.0001:raise RuntimeError('River pose did not reproduce target matrices: '+str(error))


def fit_river_cloth(root, rig, body, objects, existing=False, pose_filter=None, pose_data=None):
    data=pose_data if pose_data is not None else json.loads((root/'WorkingAssets/NPCs/river_woman/poses.json').read_text())
    conversion=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
    inverse=conversion.inverted()
    # Each imported bone may include the glTF bind-axis correction. Preserve it.
    corrections={name:(conversion@Matrix(rest)@inverse).inverted()@rig.data.bones[name].matrix_local for name,rest in data['rest'].items() if name in rig.data.bones}
    rig.animation_data_clear();rig.data.pose_position='REST'
    masks=[(modifier,modifier.show_viewport) for modifier in body.modifiers if modifier.type=='MASK']
    for modifier,_ in masks:modifier.show_viewport=False
    bpy.context.view_layer.update()
    ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());rest_mesh=ev.to_mesh();rest_mesh.calc_loop_triangles()
    human_group=body.vertex_groups['body'].index
    valid={vertex.index for vertex in body.data.vertices if any(group.group==human_group and group.weight>.5 for group in vertex.groups)}
    triangles=[tuple(triangle.vertices) for triangle in rest_mesh.loop_triangles if all(index in valid for index in triangle.vertices)]
    ev.to_mesh_clear()
    for modifier,enabled in masks:modifier.show_viewport=enabled
    rig.data.pose_position='POSE'
    for obj in objects:
        if not obj.data.shape_keys: obj.shape_key_add(name='Basis')
    for sample,pose in enumerate(data['poses']):
        if pose_filter is not None and not pose_filter(pose):continue
        apply_river_pose(rig,pose['bones'],conversion,corrections)
        bpy.context.view_layer.update()
        mask_state=[(modifier,modifier.show_viewport) for modifier in body.modifiers if modifier.type=='MASK']
        for modifier,_ in mask_state:modifier.show_viewport=False
        bpy.context.view_layer.update()
        dg=bpy.context.evaluated_depsgraph_get();ev=body.evaluated_get(dg);mesh=ev.to_mesh();mesh.calc_loop_triangles()
        points=[ev.matrix_world@vertex.co for vertex in mesh.vertices]
        normals=[(ev.matrix_world.to_3x3()@vertex.normal).normalized() for vertex in mesh.vertices]
        tree=VolumeSurface.FromPolygons(points,triangles,all_triangles=True,strict=False)
        leg_groups={group.index for group in body.vertex_groups if group.name=='pelvis' or group.name.startswith(('thigh_','calf_','foot_'))}
        foot_groups={group.index for group in body.vertex_groups if group.name.startswith(('foot_','toe'))}
        leg_ids={vertex.index for vertex in body.data.vertices if vertex.index in valid and sum(group.weight for group in vertex.groups if group.group in leg_groups)>.25}
        leg_points=[points[index] for index in leg_ids]
        leg_surface=[[points[index] for index in triangle] for triangle in triangles if all(index in leg_ids for index in triangle)]
        slope=pose.get("slope",0.0)
        floor=min(points[vertex.index].z-slope*points[vertex.index].y for vertex in body.data.vertices if vertex.index in valid and sum(group.weight for group in vertex.groups if group.group in foot_groups)>.5)
        ev.to_mesh_clear()
        for modifier,enabled in mask_state:modifier.show_viewport=enabled
        bpy.context.view_layer.update()
        for obj in objects:
            name=pose.get('key','River cloth %03d'%sample)
            key=obj.data.shape_keys.key_blocks[name] if existing else obj.shape_key_add(name=name)
            key.value=1
            if obj.name in ["Wrapped sari lower drape","Sari lower border"]:
                wrap_surface(rig,obj,key,leg_points,floor,slope,leg_surface)
            else:
                apply_surface(rig,obj,key,points,normals)
            fit_key(rig,obj,tree,key,reset_key=False)
            key.value=0
        print('RIVER_CLOTH_SAMPLE',sample,flush=True)
    for bone in rig.pose.bones: bone.matrix_basis=Matrix.Identity(4)
    rig.data.pose_position='REST'
