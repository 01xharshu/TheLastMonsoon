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
FEMALE = "--female" in sys.argv or "--fruit-seller" in sys.argv
SLUG = ("village_fruit_seller" if "--fruit-seller" in sys.argv else
        "village_weaver_assistant" if "--weaver-assistant" in sys.argv else
        "village_woman" if FEMALE else "village_farmer")
if "--purpose" in sys.argv:
    SLUG = sys.argv[sys.argv.index("--purpose") + 1]
    if SLUG not in ("dock_porter", "boatman", "record_clerk"):
        raise ValueError("Unsupported purpose role")
OUT = ROOT / "WorkingAssets/NPCs" / SLUG
bpy.ops.wm.open_mainfile(filepath=str(OUT / (SLUG + "_mpfb.blend")))
rig = bpy.data.objects[SLUG + "_rig"]
# Repair the candidate only; retain the original static source/world preview.
body = bpy.data.objects[SLUG + "_MakeHuman_body"]
import sys
sys.path.insert(0, str(ROOT / 'tools/characters'))
from whole_body_contract import retain_complete_body
retain_complete_body(body)
if "--purpose" in sys.argv:
    for modifier in body.modifiers:
        if modifier.type == 'MASK' and modifier.name != 'Hide helpers':
            modifier.show_viewport = False
            modifier.show_render = False
    body['body_retention'] = 'Complete underlying MPFB body in source and runtime; no outfit skin cutout'
if FEMALE:
    visible = body.vertex_groups['Visible period skin']
    arm_groups = {group.index for group in body.vertex_groups
                  if group.name.startswith(('upperarm_', 'lowerarm_', 'hand_'))}
    restored = [vertex.index for vertex in body.data.vertices
                if sum(g.weight for g in vertex.groups if g.group in arm_groups) > .45]
    visible.add(restored, 1.0, 'REPLACE')

# Keep the waist anchored; distribute limited thigh motion through the hem.
# Smooth left/right weights avoid a hard split through the skirt center.
drape_names = (['Wrapped sari lower drape', 'Sari lower border'] if FEMALE else
               ['Knee length wrapped dhoti', 'Dhoti woven border', 'Kurta loose lower panel'])
for name in drape_names:
    obj = bpy.data.objects.get(name)
    if obj is None:
        continue
    obj.vertex_groups.clear()
    for vertex in obj.data.vertices:
        x, y, z = vertex.co
        waist = .98 if FEMALE else .84
        hem = .13 if FEMALE else .43
        influence = .30 * max(0.0, min(1.0, (waist-z)/(waist-hem)))
        left = max(0.0, min(1.0, .5 + x/.5))
        for bone, weight in [('pelvis', 1.0-influence),
                             ('thigh_l', influence*left), ('thigh_r', influence*(1.0-left))]:
            (obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)).add([vertex.index], weight, 'REPLACE')
scene = bpy.context.scene
scene.render.fps = 30
base = {}
for bone in rig.pose.bones:
    bone.rotation_mode = 'QUATERNION'
    base[bone.name] = bone.rotation_quaternion.copy()
if "--purpose" in sys.argv and SLUG == "record_clerk":
    # Leave construction-aware room for this broader torso rather than drive
    # the upper arms into its fitted shirt/waistcoat during the gait.
    for side, sign in [('l', 1), ('r', -1)]:
        bone = rig.pose.bones['upperarm_' + side]
        axis = bone.bone.matrix_local.to_3x3().inverted() @ Vector((0, 1, 0))
        base[bone.name] = Quaternion(axis, sign * math.radians(15))
rig.animation_data_clear()
rig.animation_data_create()

gait = None
captures = []
if "--purpose" in sys.argv:
    sys.path.insert(0, str(ROOT / 'tools/characters'))
    from purpose_gait import GroundedGait
    gait = GroundedGait(rig, SLUG)

def rotate(name, world_axis, angle):
    bone = rig.pose.bones.get(name) or rig.pose.bones.get(name.replace("spine0", "spine_0"))
    if bone is None:
        return
    local_axis = bone.bone.matrix_local.to_3x3().inverted() @ Vector(world_axis)
    bone.rotation_quaternion = base[bone.name] @ Quaternion(local_axis, angle)

def relax_purpose_hands():
    for side, sign in [('l', 1), ('r', -1)]:
        middle = rig.pose.bones['middle_01_' + side]
        index = rig.pose.bones['index_01_' + side]
        pinky = rig.pose.bones['pinky_01_' + side]
        forward = (middle.bone.tail_local - middle.bone.head_local).normalized()
        across = pinky.bone.head_local - index.bone.head_local
        palm = forward.cross(across).normalized() * sign
        for finger, curl in [('index', 20), ('middle', 24), ('ring', 28), ('pinky', 32), ('thumb', 10)]:
            for joint, amount in [(1, 1.0), (2, .75), (3, .55)]:
                bone = rig.pose.bones[f'{finger}_{joint:02d}_{side}']
                tangent = (bone.bone.tail_local - bone.bone.head_local).normalized()
                axis = bone.bone.matrix_local.to_3x3().inverted() @ tangent.cross(palm).normalized()
                relaxed = Quaternion(axis, math.radians(curl * amount))
                if joint == 1 and finger != 'thumb':
                    align_axis = tangent.cross(forward)
                    if align_axis.length_squared > .000001:
                        local_axis = bone.bone.matrix_local.to_3x3().inverted() @ align_axis.normalized()
                        angle = math.acos(max(-1.0, min(1.0, tangent.dot(forward)))) * .4
                        relaxed = Quaternion(local_axis, angle) @ relaxed
                bone.rotation_quaternion = base[bone.name] @ relaxed

def pose(clip, phase):
    for bone in rig.pose.bones:
        bone.rotation_quaternion = base[bone.name].copy()
        bone.location = (0, 0, 0)
    if gait:
        relax_purpose_hands()
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
        rotate('upperarm_l', (1, 0, 0), -(gait.profile['arm'] if gait else .18) * step)
        rotate('upperarm_r', (1, 0, 0), (gait.profile['arm'] if gait else .18) * step)
        rotate('spine01', (0, 0, 1), .016 * math.sin(phase * math.tau * 2))
    bpy.context.view_layer.update()

for clip, frames in [('idle', 61), ('walk', 37)]:
    action = bpy.data.actions.new(clip)
    action.use_fake_user = True
    captured_frames = []
    rig.animation_data.action = action
    for frame in range(1, frames+1):
        phase = (frame-1) / (frames-1)
        pose(clip, phase)
        if gait:
            captured_frames.append((frame, gait.step(clip, phase)))
        for bone in rig.pose.bones:
            bone.keyframe_insert('rotation_quaternion', frame=frame, group=bone.name)
            if bone.name == 'Root':
                bone.keyframe_insert('location', frame=frame, group=bone.name)
    captures.append((action, captured_frames))
    action['loop'] = True
    action['review_status'] = 'CANDIDATE_NOT_APPROVED'

if gait:
    gait.bake(captures)
rig.animation_data.action = bpy.data.actions['idle']
scene.frame_set(1)
cloth_report = None
if gait:
    from purpose_cloth_correctives import fit_walk_cloth
    cloth_report = fit_walk_cloth(rig, body, SLUG)
source = OUT / (SLUG + "_motion_candidate.blend")
bpy.ops.wm.save_as_mainfile(filepath=str(source))
runtime = ROOT / "characters/npcs/motion" / SLUG / (SLUG + "_rigged_candidate.glb")
runtime.parent.mkdir(parents=True, exist_ok=True)
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
masked_originals = {body} if gait and outfit.data.shape_keys else {body, outfit}
# Godot does not evaluate Blender MASK modifiers on skinned clothing either.
# Bake each role's cut sleeve/vest/trouser component in rest pose, retaining
# its weights; save the fully editable source above before creating cutouts.
if "--purpose" in sys.argv:
    for original in list(bpy.data.objects):
        if original.type == 'MESH' and original not in masked_originals and any(m.type == 'MASK' for m in original.modifiers):
            bake_masked_rest(original, original.name + '_export_cutout')
            masked_originals.add(original)
bake_masked_rest(body, SLUG + ("_export_full_body" if "--purpose" in sys.argv else "_export_skin_cutout"))
if outfit in masked_originals:
    bake_masked_rest(outfit, SLUG + "_export_upper_cutout")
rig.data.pose_position = 'POSE'
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for obj in bpy.data.objects:
    if obj.type == 'MESH' and obj not in masked_originals: obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(runtime), export_format='GLB', use_selection=True,
    export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True,
    export_frame_range=False, export_cameras=False, export_lights=False,
    export_yup=True, export_skins=True, export_apply=False)
if "--purpose" in sys.argv:
    sys.path.insert(0, str(ROOT / 'tools/characters'))
    from purpose_identity import tint_glb
    tint_glb(runtime, SLUG)
    from purpose_gait import normalize_animation_times
    normalize_animation_times(runtime)
report = dict(status='MOTION_CANDIDATE_NOT_APPROVED', source=str(source.relative_to(ROOT)),
    source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
    runtime=str(runtime.relative_to(ROOT)),
    runtime_sha256=hashlib.sha256(runtime.read_bytes()).hexdigest(),
    cloth_correctives=cloth_report, actions=['idle','walk'], complete_runtime_body=True, loop_time_origin_normalized=bool(gait), gait_profile=gait.profile if gait else None,
    max_ankle_target_error_m=gait.max_target_error if gait else None,
    gait_scope='flat-floor baked foot targets; no terrain, toe-roll or full motion approval' if gait else None, motion_approved=False, in_world=SLUG in {"dock_porter", "boatman", "record_clerk"},
    garment_repair='Restored female arm skin by deform weights; waist-anchored lower drapes with up to 30% smooth thigh influence; no cloth simulation')
(OUT / 'motion_manifest.json').write_text(json.dumps(report, indent=2) + '\n')
print('VILLAGE_MOTION', json.dumps(report))

# Village rebuilds must preserve the fitted body/garment baseline as well as
# the original editable motion source. Purpose roles retain their own pipeline.
if gait is None:
    import runpy
    original_argv = sys.argv[:]
    try:
        sys.argv = ['repair_village_clothing.py', '--', SLUG]
        runpy.run_path(str(ROOT / 'tools/characters/repair_village_clothing.py'), run_name='__main__')
    finally:
        sys.argv = original_argv
