"""Fit river garments to sampled runtime poses of the unchanged MPFB body."""
import bpy, json
from mathutils import Matrix
from mathutils.bvhtree import BVHTree
from purpose_local_cloth import _fit_pose

def fit_river_cloth(root, rig, body, objects):
    data=json.loads((root/'WorkingAssets/NPCs/river_woman/poses.json').read_text())
    conversion=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
    inverse=conversion.inverted()
    # Each imported bone may include the glTF bind-axis correction. Preserve it.
    corrections={name:(conversion@Matrix(rest)@inverse).inverted()@rig.data.bones[name].matrix_local for name,rest in data['rest'].items() if name in rig.data.bones}
    rig.animation_data_clear();rig.data.pose_position='POSE'
    for obj in objects:
        if not obj.data.shape_keys: obj.shape_key_add(name='Basis')
    for sample,pose in enumerate(data['poses']):
        for bone in rig.pose.bones:
            if bone.name in pose['bones']:
                bone.matrix=conversion@Matrix(pose['bones'][bone.name])@inverse@corrections[bone.name]
        bpy.context.view_layer.update()
        dg=bpy.context.evaluated_depsgraph_get();ev=body.evaluated_get(dg);mesh=ev.to_mesh()
        tree=BVHTree.FromPolygons([ev.matrix_world@v.co for v in mesh.vertices],[tuple(p.vertices) for p in mesh.polygons]);ev.to_mesh_clear()
        for obj in objects:
            key=obj.shape_key_add(name='River cloth %03d'%sample);key.value=1
            _fit_pose(rig,obj,tree,key);key.value=0
        print('RIVER_CLOTH_SAMPLE',sample,flush=True)
    for bone in rig.pose.bones: bone.matrix_basis=Matrix.Identity(4)
    rig.data.pose_position='REST'
