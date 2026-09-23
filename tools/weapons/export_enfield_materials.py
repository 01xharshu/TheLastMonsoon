"""Bake the owner's procedural Enfield colors for glTF without saving over the source."""
import bpy
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'WorkingAssets/Arjun/weapon_enfield_p53.blend'
OUTPUT=ROOT/'environment/weapons/enfield_p53/weapon_enfield_p53_01.glb'
source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
scene=bpy.context.scene
scene.frame_set(1)
scene.render.engine='CYCLES'
scene.cycles.samples=1
meshes=[obj for obj in scene.objects if obj.type=='MESH' and obj.name.startswith('enfield_')]
assert meshes, 'No Enfield meshes found in source'
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:
    obj.hide_set(False);obj.hide_render=False;obj.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]
# Multi-object unwrap packs all components together while preserving each object's
# Generated/Object-space procedural grain during the bake.
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=1.15192,island_margin=.008)
bpy.ops.object.mode_set(mode='OBJECT')
atlas=bpy.data.images.new('Enfield_Source_BaseColor',width=2048,height=2048,alpha=False)
atlas.colorspace_settings.name='sRGB'
materials={m for obj in meshes for m in obj.data.materials if m}
outputs={}
report=[]
for mat in materials:
    nt=mat.node_tree
    bs=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
    out=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL')
    outputs[mat.name]=(out,bs)
    emit=nt.nodes.new('ShaderNodeEmission')
    if bs.inputs['Base Color'].is_linked:
        nt.links.new(bs.inputs['Base Color'].links[0].from_socket,emit.inputs['Color'])
    else:emit.inputs['Color'].default_value=bs.inputs['Base Color'].default_value
    nt.links.new(emit.outputs[0],out.inputs['Surface'])
    texture=nt.nodes.new('ShaderNodeTexImage');texture.name='Enfield baked source colors';texture.image=atlas
    nt.nodes.active=texture;texture.select=True
    report.append({'name':mat.name,'viewport_color':list(mat.diffuse_color),
        'metallic':bs.inputs['Metallic'].default_value,'roughness':bs.inputs['Roughness'].default_value})
scene.render.bake.use_clear=True
scene.render.bake.margin=12
bpy.ops.object.bake(type='EMIT')
atlas.pack()
for mat in materials:
    nt=mat.node_tree;out,bs=outputs[mat.name]
    nt.links.new(nt.nodes['Enfield baked source colors'].outputs['Color'],bs.inputs['Base Color'])
    nt.links.new(bs.outputs[0],out.inputs['Surface'])
# Export only actual gun parts and their existing parent transforms. Smoke preview
# helpers and studio objects do not belong in the carried weapon.
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:
    obj.select_set(True)
    parent=obj.parent
    while parent:
        parent.select_set(True);parent=parent.parent
bpy.context.view_layer.objects.active=meshes[0]
bpy.ops.export_scene.gltf(filepath=str(OUTPUT),export_format='GLB',use_selection=True,
    export_animations=False,export_cameras=False,export_lights=False,export_yup=True)
assert source_hash==hashlib.sha256(SOURCE.read_bytes()).hexdigest(), 'Authoring source changed'
report={'source_sha256':source_hash,'output_sha256':hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
    'method':'2048x2048 emission bake of original procedural Base Color; original metallic/roughness retained',
    'source_unchanged':True,'mesh_count':len(meshes),'materials':report}
path=ROOT/'docs/characters/arjun/enfield_material_validation.json'
path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(report,indent=2)+'\n')
print('ENFIELD_SOURCE_COLORS_EXPORTED',json.dumps(report),flush=True)
