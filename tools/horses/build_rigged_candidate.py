"""Prepare a separate CC0 rigged horse candidate for Godot review.
Source: Quaternius, Horse, https://poly.pizza/m/qvTrSG9pZF (CC0).
"""
from pathlib import Path
import bpy
root=Path(__file__).resolve().parents[2]
candidate=root/'WorkingAssets/Horse/candidates/quaternius_horse'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(candidate/'source_horse.glb'))
for obj in list(bpy.data.objects):
    if obj.type!='ARMATURE' and obj.name!='Horse':
        bpy.data.objects.remove(obj,do_unlink=True)
for mat in bpy.data.materials:
    if mat.name=='Main_Light':
        color=(0.19,0.083,0.034,1.0)
        mat.diffuse_color=color
        if mat.use_nodes:
            bsdf=mat.node_tree.nodes.get('Principled BSDF')
            if bsdf: bsdf.inputs['Base Color'].default_value=color
bpy.ops.wm.save_as_mainfile(filepath=str(candidate/'rigged_horse_candidate.blend'))
for obj in bpy.data.objects: obj.select_set(obj.type in {'ARMATURE','MESH'})
bpy.context.view_layer.objects.active=bpy.data.objects.get('AnimalArmature')
bpy.ops.export_scene.gltf(filepath=str(root/'assets/animals/horse/rigged_horse_candidate.glb'),export_format='GLB',export_yup=True,use_selection=True,export_animations=True,export_animation_mode='ACTIONS')
print('RIGGED HORSE CANDIDATE EXPORTED')
