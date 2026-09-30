"""Create an isolated Leela anatomy and face study before costume work.

Run with Blender 5.2 --background --python tools/characters/build_leela_body_study.py.
Full-body anatomy renders use neutral clay. Portraits review skin and likeness.
"""
import bpy
import hashlib
import json
import math
import sys
from pathlib import Path
from mathutils import Vector, Quaternion
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "WorkingAssets/NPCs/leela/body_study"
DATA = Path.home() / "Library/Application Support/Blender/5.2/extensions/.user/blender_org/mpfb/data"
TARGETS = Path.home() / "Library/Application Support/Blender/5.2/extensions/blender_org/mpfb/data/targets"
OUT.mkdir(parents=True, exist_ok=True)
PORTRAITS_ONLY="--portraits-only" in sys.argv
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
from bl_ext.blender_org.mpfb.services.humanservice import HumanService
from bl_ext.blender_org.mpfb.services.targetservice import TargetService

body = HumanService.create_human(macro_detail_dict=dict(
    gender=0.0, age=.47, muscle=.35, weight=.43, proportions=.48,
    height=.45, cupsize=.66, firmness=.68,
    race=dict(asian=.62, caucasian=.15, african=.23)))
body.name = "Leela_independent_body_study"
body["scope"] = "Anatomy and face study only; no costume or story placement"

# Small, editable MPFB shape keys move the generic face toward the second
# reference's oval outline, softer cheeks, larger eyes, and fuller lips.
face_targets = {
    "head/head-oval": .24,
    "head/head-fat-incr": .08,
    "head/head-round": .08,
    "head/head-invertedtriangular": .12,
    "eyes/l-eye-scale-incr": .12,
    "eyes/r-eye-scale-incr": .12,
    "eyes/l-eye-height2-incr": .07,
    "eyes/r-eye-height2-incr": .07,
    "eyebrows/eyebrows-trans-down": .06,
    "eyebrows/eyebrows-angle-up": .04,
    "cheek/l-cheek-bones-incr": .20,
    "cheek/r-cheek-bones-incr": .20,
    "nose/nose-scale-horiz-decr": .10,
    "nose/nose-scale-depth-incr": .08,
    "nose/nose-scale-vert-incr": .06,
    "nose/nose-greek-incr": .08,
    "nose/nose-width1-decr": .12,
    "nose/nose-point-width-decr": .08,
    "mouth/mouth-scale-horiz-incr": .13,
    "mouth/mouth-lowerlip-volume-incr": .02,
    "mouth/mouth-cupidsbow-incr": .10,
    "mouth/mouth-scale-vert-decr": .12,
    "chin/chin-height-decr": .25,
    "cheek/l-cheek-volume-incr": .22,
    "cheek/r-cheek-volume-incr": .22,
    "chin/chin-width-decr": .18,
    "chin/chin-bones-decr": .16,
    "mouth/mouth-angles-up": .22,
    "chin/chin-jaw-drop-decr": .08,
}
for name, value in face_targets.items():
    target = TARGETS / (name + ".target.gz")
    if not target.is_file():
        raise FileNotFoundError(target)
    TargetService.load_target(body, str(target), weight=value)
close_mouth=TargetService.load_target(body,
    str(TARGETS/"expression/units/asian/mouth-open.target.gz"),weight=0)
close_mouth.slider_min=-1
close_mouth.value=-.045

# Fit facial spacing/outline from the supplied frontal portrait. This key is
# local to the head and is applied before the rig and accessory fitting.
sys.path.insert(0,str(Path(__file__).parent))
from fit_leela_face import apply_reference_fit
reference_fit=apply_reference_fit(body)

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
clay = material("Neutral anatomy review clay", (.34,.35,.36))
lip = material("Natural lip tone", (.26,.093,.072),
    DATA/"skins/young_asian_female/young_lightskinned_female_diffuse3.png")
next(n for n in lip.node_tree.nodes if n.type=='MIX_RGB').inputs[2].default_value=(.52,.27,.235,1)
lip.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value=.48
bindi = material("Small dark bindi", (.10,.035,.03))
body.data.materials.clear()
body.data.materials.append(skin)
body.data.materials.append(lip)
lip_group=body.vertex_groups.get("lips")
lip_ids={v.index for v in body.data.vertices if lip_group and
         any(g.group==lip_group.index and g.weight>.3 for g in v.groups)}
for polygon in body.data.polygons:
    polygon.material_index = 1 if all(i in lip_ids for i in polygon.vertices) else 0
    polygon.use_smooth = True

# Fine-scale skin relief is restrained so the facial shape stays legible.
skin_bs=skin.node_tree.nodes.get("Principled BSDF")
skin_bs.inputs["Roughness"].default_value=.55
skin_bs.inputs["Subsurface Weight"].default_value=.045
noise=skin.node_tree.nodes.new("ShaderNodeTexNoise")
coords=skin.node_tree.nodes.new("ShaderNodeTexCoord")
skin.node_tree.links.new(coords.outputs["Object"],noise.inputs["Vector"])
noise.inputs["Scale"].default_value=850
noise.inputs["Detail"].default_value=2
bump=skin.node_tree.nodes.new("ShaderNodeBump")
bump.inputs["Strength"].default_value=.08
bump.inputs["Distance"].default_value=.0003
skin.node_tree.links.new(noise.outputs["Fac"],bump.inputs["Height"])
skin.node_tree.links.new(bump.outputs["Normal"],skin_bs.inputs["Normal"])
sub=body.modifiers.new("Anatomy surface refinement",'SUBSURF')
sub.levels=1;sub.render_levels=2

eyes = HumanService.add_mhclo_asset(str(DATA / "eyes/high-poly/high-poly.mhclo"),
    body, asset_type="Eyes", subdiv_levels=0)
eyes.name = "Leela_body_study_eyes"
eye_bs=eyes.data.materials[0].node_tree.nodes.get("Principled BSDF")
eye_bs.inputs["Roughness"].default_value=.22
eye_bs.inputs["Coat Weight"].default_value=.3
eye_bs.inputs["Coat Roughness"].default_value=.1
eye_nodes=eyes.data.materials[0].node_tree
incoming=eye_bs.inputs["Base Color"].links[0].from_socket
hsv=eye_nodes.nodes.new("ShaderNodeSeparateColor");hsv.mode='HSV'
eye_nodes.links.new(incoming,hsv.inputs[0])
iris_mask=eye_nodes.nodes.new("ShaderNodeValToRGB")
iris_mask.color_ramp.elements[0].position=.18
iris_mask.color_ramp.elements[1].position=.40
eye_nodes.links.new(hsv.outputs[1],iris_mask.inputs[0])
iris_tint=eye_nodes.nodes.new("ShaderNodeMixRGB")
iris_tint.blend_type='MULTIPLY';iris_tint.inputs[0].default_value=1
iris_tint.inputs[2].default_value=(.35,.45,.40,1)
eye_nodes.links.new(incoming,iris_tint.inputs[1])
eye_mix=eye_nodes.nodes.new("ShaderNodeMixRGB")
eye_nodes.links.new(iris_mask.outputs[0],eye_mix.inputs[0])
eye_nodes.links.new(incoming,eye_mix.inputs[1])
eye_nodes.links.new(iris_tint.outputs[0],eye_mix.inputs[2])
eye_nodes.links.new(eye_mix.outputs[0],eye_bs.inputs["Base Color"])
for asset,kind in [("eyebrow002","Eyebrows"),("eyelashes01","Eyelashes")]:
    folder="eyebrows" if kind=="Eyebrows" else "eyelashes"
    fitted=HumanService.add_mhclo_asset(str(DATA/folder/asset/(asset+".mhclo")),
        body,asset_type=kind,subdiv_levels=1)
    fitted.name="Leela_fitted_"+kind.lower()
hair = HumanService.add_mhclo_asset(str(DATA / "hair/ponytail01/ponytail01.mhclo"),
    body, asset_type="Hair", subdiv_levels=1)
hair.name = "Leela_hair_base"
# Preserve the fitted hair's strand alpha instead of replacing its card
# material with an opaque color, which makes overlapping cards look like clay.
for mat in hair.data.materials:
    bs=mat.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Roughness"].default_value=.48
    bs.inputs["Specular IOR Level"].default_value=.3
    incoming=bs.inputs["Base Color"].links[0].from_socket
    tint=mat.node_tree.nodes.new('ShaderNodeMixRGB')
    tint.blend_type='MULTIPLY';tint.inputs[0].default_value=1
    tint.inputs[2].default_value=(.22,.20,.18,1)
    mat.node_tree.links.new(incoming,tint.inputs[1])
    mat.node_tree.links.new(tint.outputs[0],bs.inputs["Base Color"])

# Locate the shaped face in evaluated space before adding its small bindi.
bpy.context.view_layer.update()
deps=bpy.context.evaluated_depsgraph_get()
eye_points=[eyes.matrix_world@v.co for v in eyes.evaluated_get(deps).data.vertices]
eye_z=(min(v.z for v in eye_points)+max(v.z for v in eye_points))/2
evaluated=body.evaluated_get(deps)
surface=BVHTree.FromPolygons([body.matrix_world@v.co for v in evaluated.data.vertices],
    [list(p.vertices) for p in evaluated.data.polygons])
hit=surface.ray_cast(Vector((0,-1,eye_z+.058)),Vector((0,1,0)),2)[0]

def sphere(name, location, scale, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=location)
    obj=bpy.context.object;obj.name=name;obj.scale=scale
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons: polygon.use_smooth=True
    return obj

if hit:
    sphere("Bindi study",tuple(hit+Vector((0,-.001,0))),(.0023,.0007,.0023),bindi)

for mod in body.modifiers:
    if mod.name.startswith("Delete."):
        mod.show_viewport=False;mod.show_render=False

blend=OUT/"leela_body_study.blend"

scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=48
scene.cycles.use_denoising=True
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
world=bpy.data.worlds.new("Neutral review world")
world.color=(.25,.25,.25);scene.world=world
for name,location,power,size in [
    ("Key",(2,-3,3),300,2.2),("Fill",(-2,-1,2),110,4)]:
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
    ("body_three_quarter",(2,-3,1.0),(0,0,.84),2.04,(720,900)),
    ("body_relaxed",(0,-3,1.0),(0,0,.84),2.04,(720,900)),
    ("face_front",(0,-2,eye_z),(0,0,eye_z-.025),.38,(900,900)),
    ("face_three_quarter",(1.5,-2,eye_z),(0,0,eye_z-.025),.40,(900,900)),
    ("face_profile",(2,0,eye_z),(0,0,eye_z-.025),.40,(900,900))]:
    if PORTRAITS_ONLY and name.startswith("body_"):
        continue
    for side,sign in [("l",1),("r",-1)]:
        bone=rig.pose.bones.get("upperarm_"+side)
        if bone:
            axis=bone.bone.matrix_local.to_3x3().inverted()@Vector((0,1,0))
            bone.rotation_mode='QUATERNION'
            bone.rotation_quaternion=Quaternion(axis,
                sign*math.radians(24) if name=="body_relaxed" else 0)
    bpy.context.view_layer.update()
    scene.view_layers[0].material_override=clay if name.startswith("body_") else None
    camera_data.ortho_scale=scale
    camera.location=location
    camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.resolution_x,scene.render.resolution_y=resolution
    scene.render.filepath=str(OUT/(name+".png"))
    bpy.ops.render.render(write_still=True)

scene.view_layers[0].material_override=None
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(blend))

manifest={"status":"BODY_AND_FACE_STUDY_NOT_APPROVED",
          "source":str(blend.relative_to(ROOT)),
          "source_sha256":hashlib.sha256(blend.read_bytes()).hexdigest(),
          "bone_count":len(rig.data.bones),
          "bust_shape_parameters":{"cupsize":.66,"firmness":.68,
              "basis":"visual reference silhouette; no bra size assigned"},
          "face_targets":face_targets,
          "reference_face_fit":reference_fit,
          "mouth_close_expression":-.045,
          "textures_packed":True,
          "anatomy_review_poses":["A pose","relaxed upper arms, 24 degree offset"],
          "clothing":"Body work only; anatomy renders use neutral clay",
          "renderer":"Cycles, 48 samples with denoising",
          "portrait_features":["fitted brows and lashes","high-poly eyes",
              "skin texture and fine relief","textured lips","fitted strand hair alpha"],
          "in_world":False}
(OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
print("LEELA_BODY_STUDY",json.dumps(manifest))
