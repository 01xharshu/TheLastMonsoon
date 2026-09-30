"""Export Dev's fitted MPFB source as isolated idle and walk studies."""
import bpy
import hashlib
import json
import math
from pathlib import Path
from mathutils import Vector, Quaternion

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "WorkingAssets/NPCs/arjun_brother"
GAME = ROOT / "characters/npcs/dev"
GAME.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(OUT / "arjun_brother_mpfb.blend"))
rig = bpy.data.objects["Brother_game_engine_rig"]
body = bpy.data.objects["Arjun_brother_independent_MakeHuman_body"]
outfit = bpy.data.objects["Dev_fitted_uniform_upper"]

scene = bpy.context.scene
scene.render.fps = 30
rig.animation_data_clear()
rig.animation_data_create()
for bone in rig.pose.bones:
    bone.rotation_mode = 'QUATERNION'
base = {bone.name: bone.rotation_quaternion.copy() for bone in rig.pose.bones}
def rotate(name, axis, amount):
    bone = rig.pose.bones.get(name)
    if bone:
        local_axis = bone.bone.matrix_local.to_3x3().inverted() @ Vector(axis)
        bone.rotation_quaternion = base[name] @ Quaternion(local_axis, amount)

for clip, frames in [("Dev_idle_study",61),("Dev_walk_study",37)]:
    action = bpy.data.actions.new(clip)
    action.use_fake_user = True
    rig.animation_data.action = action
    for frame in range(1,frames+1):
        phase = (frame-1)/(frames-1)
        wave = math.sin(phase*math.tau)
        for bone in rig.pose.bones:
            bone.rotation_quaternion = base[bone.name].copy()
            bone.location = (0,0,0)
        if clip == "Dev_idle_study":
            rotate("spine01",(1,0,0),.009*wave)
            rotate("neck_01",(0,0,1),.006*wave)
            rotate("upperarm_l",(1,0,0),.004*wave)
            rotate("upperarm_r",(1,0,0),-.004*wave)
        else:
            rotate("thigh_l",(1,0,0),.33*wave)
            rotate("thigh_r",(1,0,0),-.33*wave)
            rotate("calf_l",(1,0,0),-.25*max(0,wave))
            rotate("calf_r",(1,0,0),-.25*max(0,-wave))
            rotate("upperarm_l",(1,0,0),-.18*wave)
            rotate("upperarm_r",(1,0,0),.18*wave)
            rotate("spine01",(0,0,1),.012*math.sin(phase*math.tau*2))
        bpy.context.view_layer.update()
        deps = bpy.context.evaluated_depsgraph_get()
        lowest = 100.0
        for name in ["left leather shoe","right leather shoe"]:
            shoe = bpy.data.objects[name]
            evaluated = shoe.evaluated_get(deps)
            mesh = evaluated.to_mesh()
            lowest = min(lowest,min((evaluated.matrix_world @ vertex.co).z for vertex in mesh.vertices))
            evaluated.to_mesh_clear()
        root_bone = rig.pose.bones.get("Root")
        if root_bone:
            root_bone.location = root_bone.bone.matrix_local.to_3x3().inverted() @ Vector((0,0,-lowest))
        for bone in rig.pose.bones:
            bone.keyframe_insert("rotation_quaternion",frame=frame,group=bone.name)
            if bone.name == "Root":
                bone.keyframe_insert("location",frame=frame,group=bone.name)
    action["loop"] = True
    action["review_status"] = "CANDIDATE_NOT_APPROVED"
rig.animation_data.action = bpy.data.actions["Dev_idle_study"]
scene.frame_set(1)
source = OUT / "dev_idle_candidate.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(source))

# Godot's glTF importer ignores Blender MASK modifiers on skinned meshes.
# Bake masked rest meshes, retaining deform weights and the original source.
rig.data.pose_position = 'REST'
bpy.context.view_layer.update()
deps = bpy.context.evaluated_depsgraph_get()
def bake_masked(original, label):
    mesh = bpy.data.meshes.new_from_object(original.evaluated_get(deps),
        preserve_all_data_layers=True, depsgraph=deps)
    cutout = bpy.data.objects.new(label,mesh)
    scene.collection.objects.link(cutout)
    for group in original.vertex_groups:
        cutout.vertex_groups.new(name=group.name)
    cutout.parent = rig
    cutout.matrix_parent_inverse = original.matrix_parent_inverse.copy()
    cutout.matrix_basis = original.matrix_basis.copy()
    cutout.modifiers.new("Armature deformation",'ARMATURE').object = rig
    return cutout
bake_masked(body,"Dev_visible_skin_export")
bake_masked(outfit,"Dev_fitted_upper_export")
rig.data.pose_position = 'POSE'
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for obj in bpy.data.objects:
    if obj.type == 'MESH' and obj not in (body,outfit): obj.select_set(True)
bpy.context.view_layer.objects.active = rig
runtime = GAME / "dev_idle_candidate.glb"
bpy.ops.export_scene.gltf(filepath=str(runtime),export_format='GLB',use_selection=True,
    export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,
    export_frame_range=False,export_cameras=False,export_lights=False,
    export_yup=True,export_skins=True,export_apply=False)
report={"status":"RIGGED_MOTION_STUDY_NOT_APPROVED",
        "source":str(source.relative_to(ROOT)),
        "source_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),
        "runtime":str(runtime.relative_to(ROOT)),
        "runtime_sha256":hashlib.sha256(runtime.read_bytes()).hexdigest(),
        "actions":["Dev_idle_study","Dev_walk_study"],"in_world":False,"motion_approved":False}
(OUT/"idle_manifest.json").write_text(json.dumps(report,indent=2)+"\n")
print("DEV_IDLE",json.dumps(report))
