"""Replay native joint deformations in Blender without altering the source body."""
from mathutils import Matrix, Vector
import bpy
from math import pi


def matrix(columns, origin):
    result=Matrix.Identity(4)
    for col in range(3):
        for row in range(3):result[row][col]=columns[col][row]
    result.translation=Vector(origin)
    return result


def apply(rig, data):
    conversion=Matrix.Rotation(pi/2,4,'X')
    inverse=conversion.inverted()
    entries={entry['name']:entry for entry in data['bones']}
    rig.data.pose_position='POSE'
    targets={}
    for bone in rig.pose.bones:
        entry=entries.get(bone.name)
        if entry is None:continue
        pose=matrix(entry['basis'],entry['origin'])
        rest=matrix(entry['rest_basis'],entry['rest_origin'])
        deformation=conversion@pose@rest.inverted()@inverse
        targets[bone.name]=rig.matrix_world.inverted()@deformation@rig.matrix_world@bone.bone.matrix_local
    for bone in rig.pose.bones:
        if bone.name not in targets:continue
        arguments={}
        if bone.parent is not None:
            arguments={'parent_matrix':targets[bone.parent.name],
                       'parent_matrix_local':bone.parent.bone.matrix_local}
        bone.matrix_basis=bone.bone.convert_local_to_pose(
            targets[bone.name],bone.bone.matrix_local,invert=True,**arguments)
    bpy.context.view_layer.update()
    error=max(max(abs(value) for row in (bone.matrix-targets[bone.name]) for value in row)
              for bone in rig.pose.bones if bone.name in targets)
    if error>.0001:raise RuntimeError('Native replay target matrices disagree: '+str(error))
