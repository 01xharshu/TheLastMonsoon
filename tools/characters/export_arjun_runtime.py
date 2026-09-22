"""Export the existing clothed Arjun base; never modify the authoring blend."""
import bpy
from pathlib import Path
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'WorkingAssets/Arjun/arjun_character_v2.blend'))
keep = {'Human','Human.high-poly','Human.eyebrow012','Human.short01','FACIAL_Moustache_Arjun','CLOTH_Arjun_Kurta_Upper','CLOTH_Arjun_Kurta_WaistExtension','CLOTH_Arjun_Lungi'}
for ob in list(bpy.data.objects):
    if ob.name not in keep:
        bpy.data.objects.remove(ob, do_unlink=True)
for ob in bpy.context.scene.objects:
    matrix = ob.matrix_world.copy()
    ob.parent = None
    ob.matrix_world = matrix
    ob.hide_set(False)
    ob.hide_render = False
body = bpy.data.objects['Human']
for modifier in list(body.modifiers):
    if modifier.name != 'Hide helpers': body.modifiers.remove(modifier)
from bl_ext.blender_org.mpfb.services.humanservice import HumanService
rig = HumanService.add_builtin_rig(body, 'game_engine', import_weights=True)
rig.name = 'Arjun_Rig'
print('RIG BONES', [b.name for b in rig.data.bones])
# Bake evaluated helper masks before exporting; preserve skin weights.
for ob in list(bpy.context.scene.objects):
    if ob.type not in {'MESH', 'CURVE'}: continue
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.convert(target='MESH')
arm = body.modifiers.new('Arjun rig', 'ARMATURE')
arm.object = rig
# Transfer body weights by nearest surface for the existing fitted clothing and hair.
for ob in list(bpy.context.scene.objects):
    if ob.type != 'MESH' or ob == body: continue
    for group in body.vertex_groups:
        if not ob.vertex_groups.get(group.name): ob.vertex_groups.new(name=group.name)
    bpy.context.view_layer.objects.active = ob
    mod = ob.modifiers.new('Body weights', 'DATA_TRANSFER')
    mod.object = body
    mod.use_vert_data = True
    mod.data_types_verts = {'VGROUP_WEIGHTS'}
    mod.vert_mapping = 'POLYINTERP_NEAREST'
    bpy.ops.object.modifier_apply(modifier=mod.name)
    arm = ob.modifiers.new('Arjun rig', 'ARMATURE')
    arm.object = rig
for ob in bpy.context.scene.objects:
    if ob.type == 'MESH':
        matrix = ob.matrix_world.copy()
        ob.parent = rig
        ob.matrix_world = matrix
# Self-contained embedded textures from the project copies.
for image in bpy.data.images:
    candidate = ROOT / 'WorkingAssets/Arjun' / ('arjun_character_v2_' + Path(image.filepath).name)
    if candidate.exists():
        image.filepath = str(candidate)
        image.reload()
out = ROOT / 'characters/arjun'
out.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(out / 'arjun.glb'), export_format='GLB', export_animations=False, export_yup=True)
