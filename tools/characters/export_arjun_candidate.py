"""Color-preserving export of the selected improved candidate with authored clips.

Bakes original shader color and alpha into a shared atlas. Keeps the editable
MakeHuman source and foundation in the Blender working files.
"""
import bpy
import numpy as np
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'WorkingAssets/Arjun/candidate/arjun_animated_candidate.blend'
OUT=ROOT/'characters/arjun/arjun.glb'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene=bpy.context.scene
rig=bpy.data.objects['Arjun_Rig']
rig.data.pose_position='REST'
scene.frame_set(1)
meshes=[o for o in scene.objects if o.type=='MESH' and o.parent==rig and not o.hide_render]
for obj in meshes:
    # Apply the evaluated body targets, helper masks, thickness and subdivision in
    # rest pose, preserving bone groups. No posed geometry is baked into the bind.
    bpy.ops.object.select_all(action='DESELECT');obj.hide_set(False);obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.convert(target='MESH')
    for mod in list(obj.modifiers):obj.modifiers.remove(mod)
    arm=obj.modifiers.new('Arjun skin','ARMATURE');arm.object=rig
    obj.parent=rig
    # Preserve the source UV coordinates used by all image nodes during baking.
    old_uv=obj.data.uv_layers.active
    if old_uv is None:old_uv=obj.data.uv_layers.new(name='SourceUV')
    old_name=old_uv.name
    for mat in obj.data.materials:
        if not mat or not mat.node_tree:continue
        for n in list(mat.node_tree.nodes):
            if n.type=='TEX_IMAGE' and not n.inputs['Vector'].is_linked:
                uv=mat.node_tree.nodes.new('ShaderNodeUVMap');uv.uv_map=old_name
                mat.node_tree.links.new(uv.outputs['UV'],n.inputs['Vector'])
    uv=obj.data.uv_layers.new(name='Arjun_Atlas_UV')
    obj.data.uv_layers.active_index=len(obj.data.uv_layers)-1
    uv.active_render=True
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=1.15192,island_margin=.004)
bpy.ops.object.mode_set(mode='OBJECT')
scene.render.engine='CYCLES';scene.cycles.samples=1
scene.render.bake.margin=8;scene.render.bake.use_clear=True
atlas=bpy.data.images.new('Arjun_BaseColor_Atlas',width=2048,height=2048,alpha=True)
alpha=bpy.data.images.new('Arjun_Alpha_Atlas',width=2048,height=2048,alpha=False)
alpha.colorspace_settings.name='Non-Color'
materials={m for obj in meshes for m in obj.data.materials if m}
saved={}
for mat in materials:
    nt=mat.node_tree
    bs=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
    out=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL')
    emit=nt.nodes.new('ShaderNodeEmission')
    color_link=bs.inputs['Base Color'].links[0].from_socket if bs.inputs['Base Color'].is_linked else None
    alpha_link=bs.inputs['Alpha'].links[0].from_socket if bs.inputs['Alpha'].is_linked else None
    if color_link:nt.links.new(color_link,emit.inputs['Color'])
    else:emit.inputs['Color'].default_value=bs.inputs['Base Color'].default_value
    nt.links.new(emit.outputs[0],out.inputs['Surface'])
    image_node=nt.nodes.new('ShaderNodeTexImage');image_node.image=atlas
    nt.nodes.active=image_node
    saved[mat.name]=(bs,out,emit,image_node,alpha_link,bs.inputs['Alpha'].default_value)
bpy.ops.object.bake(type='EMIT')
print('ARJUN COLOR ATLAS BAKED',flush=True)
for mat in materials:
    bs,out,emit,node,alpha_link,value=saved[mat.name]
    nt=mat.node_tree
    for link in list(emit.inputs['Color'].links):nt.links.remove(link)
    if alpha_link:nt.links.new(alpha_link,emit.inputs['Color'])
    else:emit.inputs['Color'].default_value=(value,value,value,1)
    node.image=alpha
bpy.ops.object.bake(type='EMIT')
pixels=np.empty(2048*2048*4,dtype=np.float32);atlas.pixels.foreach_get(pixels)
alphas=np.empty_like(pixels);alpha.pixels.foreach_get(alphas)
pixels[3::4]=np.clip(alphas[0::4],0,1)
atlas.pixels.foreach_set(pixels);atlas.update();atlas.pack()
for mat in materials:
    bs,out,emit,node,alpha_link,value=saved[mat.name]
    nt=mat.node_tree;node.image=atlas
    uv=nt.nodes.new('ShaderNodeUVMap');uv.uv_map='Arjun_Atlas_UV'
    nt.links.new(uv.outputs['UV'],node.inputs['Vector'])
    nt.links.new(node.outputs['Color'],bs.inputs['Base Color'])
    if alpha_link or value<1:
        nt.links.new(node.outputs['Alpha'],bs.inputs['Alpha'])
        mat.surface_render_method='DITHERED'
    nt.links.new(bs.outputs[0],out.inputs['Surface'])
rig.data.pose_position='POSE'
rig.animation_data.action=bpy.data.actions['idle']
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',use_selection=True,
    export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,
    export_frame_range=False,export_cameras=False,export_lights=False,export_yup=True,
    export_skins=True,export_apply=False)
report={'source':str(SOURCE.relative_to(ROOT)),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'output':str(OUT.relative_to(ROOT)),'output_sha256':hashlib.sha256(OUT.read_bytes()).hexdigest(),
    'meshes':len(meshes),'bones':len(rig.data.bones),'actions':[a.name for a in bpy.data.actions if a.name in ['idle','walk','sit_down','sit_idle','stand_up','prone_down','prone_idle','prone_up','swim_forward','swim_idle']],
    'color_method':'Source material color and alpha baked into 2048 atlas; original metallic/roughness retained',
    'owner_direction':'Use improved candidate as playable base; continue refinement',
    'final_likeness_approved':False,'motion_approved':False}
(ROOT/'docs/characters/arjun/runtime_export.json').write_text(json.dumps(report,indent=2)+'\n')
print('ARJUN_PLAYABLE_CANDIDATE_EXPORTED',json.dumps(report),flush=True)
