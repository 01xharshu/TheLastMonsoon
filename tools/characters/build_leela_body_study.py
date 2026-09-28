"""Create an isolated Leela anatomy and face study before costume work.

Run with Blender 5.2 --background --python tools/characters/build_leela_body_study.py.
The dark material is temporary body-study coverage, not costume design.
"""
import bpy
import hashlib
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "WorkingAssets/NPCs/leela/body_study"
DATA = Path.home() / "Library/Application Support/Blender/5.2/extensions/.user/blender_org/mpfb/data"
TARGETS = Path.home() / "Library/Application Support/Blender/5.2/extensions/blender_org/mpfb/data/targets"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
from bl_ext.blender_org.mpfb.services.humanservice import HumanService
from bl_ext.blender_org.mpfb.services.targetservice import TargetService

body = HumanService.create_human(macro_detail_dict=dict(
    gender=0.0, age=.47, muscle=.35, weight=.43, proportions=.48,
    height=.45, cupsize=.46, firmness=.55,
    race=dict(asian=.62, caucasian=.15, african=.23)))
body.name = "Leela_independent_body_study"
body["scope"] = "Anatomy and face study only; no costume or story placement"

# Small, editable MPFB shape keys move the generic face toward the second
# reference's oval outline, softer cheeks, larger eyes, and fuller lips.
face_targets = {
    "head/head-oval": .24,
    "head/head-scale-horiz-decr": .08,
    "eyes/l-eye-scale-incr": .06,
    "eyes/r-eye-scale-incr": .06,
    "cheek/l-cheek-bones-incr": .12,
    "cheek/r-cheek-bones-incr": .12,
    "nose/nose-scale-horiz-decr": .10,
    "mouth/mouth-lowerlip-volume-incr": .15,
    "mouth/mouth-upperlip-volume-incr": .10,
    "chin/chin-width-decr": .09,
}
for name, value in face_targets.items():
    target = TARGETS / (name + ".target.gz")
    if not target.is_file():
        raise FileNotFoundError(target)
    TargetService.load_target(body, str(target), weight=value)

rig = HumanService.add_builtin_rig(body, "game_engine", import_weights=True)
rig.name = "Leela_body_study_game_engine_rig"

def material(name, color, texture=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_fake_user = True
    mat.diffuse_color = (*color, 1)
    bs = mat.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*color, 1)
    bs.inputs["Roughness"].default_value = .83
    if texture:
        node = mat.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(str(texture), check_existing=True)
        mix = mat.node_tree.nodes.new("ShaderNodeMixRGB")
        mix.blend_type = 'MULTIPLY'
        mix.inputs[0].default_value = 1.0
        mix.inputs[2].default_value = (.48,.36,.29,1.0)
        mat.node_tree.links.new(node.outputs["Color"],mix.inputs[1])
        mat.node_tree.links.new(mix.outputs[0],bs.inputs["Base Color"])
    return mat

skin = material("Warm skin with MPFB texture", (.48,.32,.24),
    DATA / "skins/young_asian_female/young_lightskinned_female_diffuse3.png")
coverage = material("Neutral body-study coverage", (.18,.19,.19))
dark = material("Dark brown hair", (.027,.018,.015))
red = material("Hair ribbon reference cue", (.32,.07,.06))
bindi = material("Small dark bindi", (.10,.035,.03))
body.data.materials.clear()
body.data.materials.append(skin)
body.data.materials.append(coverage)
for polygon in body.data.polygons:
    center = polygon.center
    x,z = abs(center.x),center.z
    polygon.material_index = 1 if ((x < .30 and .65 < z < 1.23) or
                                   (x < .25 and .42 < z <= .65)) else 0
    polygon.use_smooth = True

eyes = HumanService.add_mhclo_asset(str(DATA / "eyes/low-poly/low-poly.mhclo"),
    body, asset_type="Eyes", subdiv_levels=0)
eyes.name = "Leela_body_study_eyes"
hair = HumanService.add_mhclo_asset(str(DATA / "hair/ponytail01/ponytail01.mhclo"),
    body, asset_type="Hair", subdiv_levels=0)
hair.name = "Leela_hair_base"
hair.data.materials.clear(); hair.data.materials.append(dark)
for polygon in hair.data.polygons: polygon.material_index = 0

# Only hair and facial identity cues are developed here. The bun and a few
# loose strands remain separate meshes so their position can be revised.
def sphere(name, location, scale, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=location)
    obj=bpy.context.object;obj.name=name;obj.scale=scale
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons: polygon.use_smooth=True
    return obj

sphere("High loosely gathered hair",(0,.085,1.379),(.072,.062,.050),dark)
sphere("Hair tie",(0,.142,1.365),(.059,.012,.018),red)
sphere("Bindi study",(0,-.114,1.338),(.007,.003,.007),bindi)

def strand(name, points, radius):
    curve=bpy.data.curves.new(name,'CURVE')
    curve.dimensions='3D';curve.bevel_depth=radius;curve.bevel_resolution=2
    spline=curve.splines.new('BEZIER')
    spline.bezier_points.add(len(points)-1)
    for point,position in zip(spline.bezier_points,points):
        point.co=position;point.handle_left_type='AUTO';point.handle_right_type='AUTO'
    obj=bpy.data.objects.new(name,curve)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(dark)
    return obj

for side in (-1,1):
    strand("Face framing curl %s" % side,
        [(side*.071,-.075,1.365),(side*.080,-.113,1.333),
         (side*.086,-.107,1.295),(side*.092,-.091,1.262)],.0035)
    strand("Dark eyebrow %s" % side,
        [(side*.014,-.124,1.319),(side*.035,-.129,1.327),
         (side*.061,-.118,1.322)],.0035)

for mod in body.modifiers:
    if mod.name.startswith("Delete."):
        mod.show_viewport=False;mod.show_render=False

blend=OUT/"leela_body_study.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(blend))

scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
world=bpy.data.worlds.new("Neutral review world")
world.color=(.25,.25,.25);scene.world=world
for name,location,power,size in [
    ("Key",(2,-3,3),300,4),("Fill",(-2,-1,2),130,4)]:
    light=bpy.data.lights.new(name,'AREA');light.energy=power;light.shape='DISK';light.size=size
    lamp=bpy.data.objects.new(name,light);scene.collection.objects.link(lamp)
    lamp.location=location
    lamp.rotation_euler=(Vector((0,0,1.1))-lamp.location).to_track_quat('-Z','Y').to_euler()
camera_data=bpy.data.cameras.new("Review camera")
camera_data.type='ORTHO'
camera=bpy.data.objects.new("Review camera",camera_data)
scene.collection.objects.link(camera);scene.camera=camera
for name,location,target,scale,resolution in [
    ("body_front",(0,-3,1.0),(0,0,.84),2.04,(720,900)),
    ("body_side",(3,0,1.0),(0,0,.84),2.04,(720,900)),
    ("body_back",(0,3,1.0),(0,0,.84),2.04,(720,900)),
    ("face_front",(0,-2,1.30),(0,0,1.30),.52,(720,720)),
    ("face_three_quarter",(1.5,-2,1.30),(0,0,1.30),.56,(720,720))]:
    camera_data.ortho_scale=scale
    camera.location=location
    camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.resolution_x,scene.render.resolution_y=resolution
    scene.render.filepath=str(OUT/(name+".png"))
    bpy.ops.render.render(write_still=True)

manifest={"status":"BODY_AND_FACE_STUDY_NOT_APPROVED",
          "source":str(blend.relative_to(ROOT)),
          "source_sha256":hashlib.sha256(blend.read_bytes()).hexdigest(),
          "bone_count":len(rig.data.bones),
          "face_targets":face_targets,
          "clothing":"neutral shader coverage only",
          "in_world":False}
(OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
print("LEELA_BODY_STUDY",json.dumps(manifest))
