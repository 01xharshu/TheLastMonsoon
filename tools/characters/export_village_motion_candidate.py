"""Export isolated rigged idle/walk studies for the Indian village pair.

Run with Blender --background --python this_file -- [--female]. These are review
candidates; the visible world pair keeps its separately validated static mesh.
"""
import bpy
import hashlib
import json
import math
import sys
from pathlib import Path
from mathutils import Vector, Quaternion

ROOT = Path(__file__).resolve().parents[2]
FEMALE = "--female" in sys.argv
SLUG = "village_woman" if FEMALE else "village_farmer"
OUT = ROOT / "WorkingAssets/NPCs" / SLUG
bpy.ops.wm.open_mainfile(filepath=str(OUT / (SLUG + "_mpfb.blend")))
rig = bpy.data.objects[SLUG + "_rig"]
scene = bpy.context.scene
scene.render.fps = 30
base = {}
for bone in rig.pose.bones:
    bone.rotation_mode = 'QUATERNION'
    base[bone.name] = bone.rotation_quaternion.copy()
rig.animation_data_clear()
rig.animation_data_create()

def rotate(name, world_axis, angle):
    bone = rig.pose.bones.get(name)
    if bone is None:
        return
    local_axis = bone.bone.matrix_local.to_3x3().inverted() @ Vector(world_axis)
    bone.rotation_quaternion = base[name] @ Quaternion(local_axis, angle)

def pose(clip, phase):
    for bone in rig.pose.bones:
        bone.rotation_quaternion = base[bone.name].copy()
        bone.location = (0, 0, 0)
    if clip == 'idle':
        breathe = math.sin(phase * math.tau)
        rotate('spine01', (1, 0, 0), .008 * breathe)
        rotate('neck_01', (0, 0, 1), .009 * breathe)
        for side, sign in [('l', 1), ('r', -1)]:
            rotate('upperarm_' + side, (1, 0, 0), .015 * breathe * sign)
    else:
        step = math.sin(phase * math.tau)
        lift_l = max(0, step)
        lift_r = max(0, -step)
        rotate('thigh_l', (1, 0, 0), .30 * step)
        rotate('thigh_r', (1, 0, 0), -.30 * step)
        rotate('calf_l', (1, 0, 0), -.27 * lift_l)
        rotate('calf_r', (1, 0, 0), -.27 * lift_r)
        rotate('upperarm_l', (1, 0, 0), -.18 * step)
        rotate('upperarm_r', (1, 0, 0), .18 * step)
        rotate('spine01', (0, 0, 1), .016 * math.sin(phase * math.tau * 2))
    bpy.context.view_layer.update()

for clip, frames in [('idle', 61), ('walk', 37)]:
    action = bpy.data.actions.new(clip)
    action.use_fake_user = True
    rig.animation_data.action = action
    for frame in range(1, frames+1):
        phase = (frame-1) / (frames-1)
        pose(clip, phase)
        for bone in rig.pose.bones:
            bone.keyframe_insert('rotation_quaternion', frame=frame, group=bone.name)
            if bone.name == 'Root':
                bone.keyframe_insert('location', frame=frame, group=bone.name)
    action['loop'] = True
    action['review_status'] = 'CANDIDATE_NOT_APPROVED'

rig.animation_data.action = bpy.data.actions['idle']
scene.frame_set(1)
source = OUT / (SLUG + "_motion_candidate.blend")
bpy.ops.wm.save_as_mainfile(filepath=str(source))
runtime = OUT / (SLUG + "_rigged_candidate.glb")
# Godot's glTF importer does not apply MPFB's body MASK modifiers to a skinned
# mesh. Bake only the covered-body cutout in rest pose, retaining deform weights
# and the original morphable body in the saved Blender source.
body = bpy.data.objects[SLUG + "_MakeHuman_body"]
outfit = bpy.data.objects["Fitted cotton upper base"]
rig.data.pose_position = 'REST'
bpy.context.view_layer.update()
depsgraph = bpy.context.evaluated_depsgraph_get()
def bake_masked_rest(original, label):
    cutout_mesh = bpy.data.meshes.new_from_object(original.evaluated_get(depsgraph),
        preserve_all_data_layers=True, depsgraph=depsgraph)
    cutout = bpy.data.objects.new(label, cutout_mesh)
    bpy.context.scene.collection.objects.link(cutout)
    for group in original.vertex_groups:
        cutout.vertex_groups.new(name=group.name)
    cutout.parent = rig
    cutout.matrix_parent_inverse = original.matrix_parent_inverse.copy()
    cutout.matrix_basis = original.matrix_basis.copy()
    cutout.modifiers.new('Armature deformation', 'ARMATURE').object = rig
    return cutout
bake_masked_rest(body, SLUG + "_export_skin_cutout")
bake_masked_rest(outfit, SLUG + "_export_upper_cutout")
rig.data.pose_position = 'POSE'
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for obj in bpy.data.objects:
    if obj.type == 'MESH' and obj not in (body, outfit): obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(runtime), export_format='GLB', use_selection=True,
    export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True,
    export_frame_range=False, export_cameras=False, export_lights=False,
    export_yup=True, export_skins=True, export_apply=False)
report = dict(status='MOTION_CANDIDATE_NOT_APPROVED', source=str(source.relative_to(ROOT)),
    source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
    runtime=str(runtime.relative_to(ROOT)),
    runtime_sha256=hashlib.sha256(runtime.read_bytes()).hexdigest(),
    actions=['idle','walk'], motion_approved=False, in_world=False)
(OUT / 'motion_manifest.json').write_text(json.dumps(report, indent=2) + '\n')
print('VILLAGE_MOTION', json.dumps(report))
