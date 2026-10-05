"""Build Leela's isolated, editable first-pass character study in Blender 5.2."""
import bpy
import hashlib
import json
import math
from pathlib import Path
from mathutils import Vector, Quaternion

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "WorkingAssets/NPCs/leela/candidate"
DATA = Path.home() / "Library/Application Support/Blender/5.2/extensions/.user/blender_org/mpfb/data"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
from bl_ext.blender_org.mpfb.services.humanservice import HumanService

body = HumanService.create_human(macro_detail_dict=dict(
    gender=0.0, age=.36, muscle=.38, weight=.43, proportions=.49, height=.45,
    cupsize=.49, firmness=.55, race=dict(asian=.62, caucasian=.15, african=.23)))
body.name = "Leela_independent_MakeHuman_body"
body["review_status"] = "FIRST_PASS_NOT_APPROVED"
rig = HumanService.add_builtin_rig(body, "game_engine", import_weights=True)
rig.name = "Leela_game_engine_rig"

def material(name, color, texture=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_fake_user = True
    mat.diffuse_color = (*color, 1)
    bs = mat.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*color, 1)
    bs.inputs["Roughness"].default_value = .87
    if texture:
        image = mat.node_tree.nodes.new("ShaderNodeTexImage")
        image.image = bpy.data.images.load(str(texture), check_existing=True)
        mat.node_tree.links.new(image.outputs["Color"], bs.inputs["Base Color"])
    return mat

skin = material("Warm skin study", (.49,.32,.22))
hair_mat = material("Dark brown hair", (.026,.017,.014))
green = material("Deep green tunic", (.07,.105,.083))
red = material("Rust red drape", (.37,.08,.065))
trim = material("Muted copper embroidery", (.49,.28,.16))
cotton = material("Light cotton trousers", (.69,.65,.55))
leather = material("Dark brown leather", (.15,.075,.043))
brass = material("Aged brass jewelry", (.53,.36,.16))
body.data.materials.clear(); body.data.materials.append(skin)
for face in body.data.polygons:
    face.use_smooth = True
    face.material_index = 0

eyes = HumanService.add_mhclo_asset(str(DATA / "eyes/low-poly/low-poly.mhclo"),
    body, asset_type="Eyes", subdiv_levels=0)
eyes.name = "Leela_eyes"
hair = HumanService.add_mhclo_asset(str(DATA / "hair/ponytail01/ponytail01.mhclo"),
    body, asset_type="Hair", subdiv_levels=0)
hair.name = "Leela_hair_study"
hair.data.materials.clear(); hair.data.materials.append(hair_mat)
for face in hair.data.polygons: face.material_index = 0

outfit_name = "female_casualsuit01"
outfit = HumanService.add_mhclo_asset(str(DATA / "clothes" / outfit_name /
    (outfit_name + ".mhclo")), body, asset_type="Clothes", subdiv_levels=0)
outfit.name = "Leela_fitted_upper_study"
outfit.data.materials.clear(); outfit.data.materials.append(green)
for face in outfit.data.polygons: face.material_index = 0

# Retain the fitted upper component only. The rest is replaced by simple
# editable study geometry so the lower silhouette can be revised independently.
parents = list(range(len(outfit.data.vertices)))
def find(index):
    while parents[index] != index:
        parents[index] = parents[parents[index]]
        index = parents[index]
    return index
for edge in outfit.data.edges:
    parents[find(edge.vertices[0])] = find(edge.vertices[1])
components = {}
for vertex in outfit.data.vertices:
    root = find(vertex.index)
    components.setdefault(root, []).append(vertex.index)
upper = max(components.values(), key=lambda ids: max(outfit.data.vertices[i].co.z for i in ids))
group = outfit.vertex_groups.new(name="Fitted upper only")
group.add(upper, 1, 'REPLACE')
mask = outfit.modifiers.new("Keep fitted upper", 'MASK')
mask.vertex_group = group.name

def mesh(name, vertices, faces, mat, bone):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces); data.update()
    data.materials.append(mat)
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    for face in data.polygons: face.use_smooth = True
    obj.parent = rig
    vg = obj.vertex_groups.new(name=bone)
    vg.add(list(range(len(vertices))), 1, 'REPLACE')
    obj.modifiers.new("Rig", 'ARMATURE').object = rig
    return obj

def rings(name, levels, mat, bone="spine01", sides=28):
    vertices = []
    for z, rx, ry, cx, cy in levels:
        vertices.extend((cx+rx*math.cos(i*math.tau/sides),
                         cy+ry*math.sin(i*math.tau/sides), z) for i in range(sides))
    faces = [(r*sides+i, r*sides+(i+1)%sides,
              (r+1)*sides+(i+1)%sides, (r+1)*sides+i)
             for r in range(len(levels)-1) for i in range(sides)]
    return mesh(name, vertices, faces, mat, bone)

def ribbon(name, points, width, mat, bone="spine01"):
    vertices = []
    for x,y,z in points:
        vertices.extend([(x-width/2,y,z),(x+width/2,y,z)])
    faces = [(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(points)-1)]
    return mesh(name, vertices, faces, mat, bone)

def cylinder(name, start, end, radii, mat, bone, sides=14):
    a,b = Vector(start),Vector(end)
    axis = (b-a).normalized()
    u = axis.cross(Vector((0,1,0))).normalized()
    v = axis.cross(u).normalized()
    vertices = [tuple(center+radius*(math.cos(i*math.tau/sides)*u+
                 math.sin(i*math.tau/sides)*v))
                for center,radius in ((a,radii[0]),(b,radii[1])) for i in range(sides)]
    faces = [(i,(i+1)%sides,sides+(i+1)%sides,sides+i) for i in range(sides)]
    return mesh(name, vertices, faces, mat, bone)

# First sheet's covered, travel-ready costume is the starting silhouette.
rings("Asymmetric tunic skirt study", [(.67,.27,.25,0,0),(.79,.26,.23,0,0),
    (.96,.20,.17,0,0),(1.05,.16,.13,0,0)], green)
rings("Tunic hem trim", [(.68,.272,.252,0,0),(.70,.271,.251,0,0)], trim)
rings("Leather waist wrap", [(.96,.215,.182,0,0),(.99,.215,.182,0,0)], leather)
for sign,side in [(1,"left"),(-1,"right")]:
    suffix = "l" if sign==1 else "r"
    cylinder(side+" cotton trouser",(sign*.12,0,.83),(sign*.12,0,.22),
             (.13,.105),cotton,"thigh_"+suffix)
    cylinder(side+" leather boot",(sign*.12,0,.31),(sign*.12,0,.08),
             (.108,.11),leather,"calf_"+suffix)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,
        location=(sign*.12,-.067,.058))
    shoe = bpy.context.object; shoe.name = side+" boot toe"
    shoe.scale=(.112,.18,.06); shoe.data.materials.append(leather)
    shoe.parent=rig
    vg=shoe.vertex_groups.new(name="foot_"+suffix)
    vg.add(list(range(len(shoe.data.vertices))),1,'REPLACE')
    shoe.modifiers.new("Rig",'ARMATURE').object=rig

# A broad shoulder-to-waist drape and hanging tail make the red fabric legible.
ribbon("Red front drape", [(-.17,-.13,1.02),(-.18,-.205,.90),
    (-.06,-.218,.79),(.14,-.18,.64)], .11, red)
ribbon("Red back drape", [(-.17,.13,1.02),(-.19,.19,.84),
    (-.17,.245,.64),(-.16,.257,.44)], .12, red)
ribbon("Red drape border", [(-.225,-.143,1.02),(-.235,-.208,.90),
    (-.115,-.221,.79),(.085,-.184,.64)], .012, trim)

# Face, hair, jewelry and scarf need dedicated sculpting and cloth work.

visible = body.vertex_groups.new(name="Visible skin")
indices = [v.index for v in body.data.vertices if v.co.z>1.41 or
           (abs(v.co.x)>.34 and .84<v.co.z<1.39)]
visible.add(indices,1,'REPLACE')
body_mask=body.modifiers.new("Hide clothed skin",'MASK')
body_mask.vertex_group=visible.name
body_mask.show_viewport=False;body_mask.show_render=False
for mod in body.modifiers:
    if mod.name.startswith("Delete."):
        mod.show_viewport=False; mod.show_render=False

for side,sign in [("l",1),("r",-1)]:
    bone=rig.pose.bones.get("upperarm_"+side)
    if bone:
        axis=bone.bone.matrix_local.to_3x3().inverted() @ Vector((0,1,0))
        bone.rotation_mode='QUATERNION'
        bone.rotation_quaternion=Quaternion(axis,sign*math.radians(28))
rig.data.pose_position='POSE'

source=OUT/"leela_mpfb_study.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(source))
bpy.context.view_layer.update()
deps=bpy.context.evaluated_depsgraph_get()
for obj in list(bpy.data.objects):
    if obj.type!='MESH': continue
    baked=bpy.data.meshes.new_from_object(obj.evaluated_get(deps),
        preserve_all_data_layers=True,depsgraph=deps)
    copy=bpy.data.objects.new(obj.name+"_preview",baked)
    bpy.context.scene.collection.objects.link(copy)
    copy.matrix_world=obj.matrix_world.copy()
    obj.hide_render=True; obj.select_set(False); copy.select_set(True)
preview=OUT/"leela_static_study.glb"
bpy.ops.export_scene.gltf(filepath=str(preview),export_format='GLB',
    use_selection=True,export_animations=False,export_cameras=False,
    export_lights=False,export_skins=False)

scene=bpy.context.scene; scene.render.engine='BLENDER_EEVEE'
scene.view_settings.view_transform='Standard'
scene.render.resolution_x=720;scene.render.resolution_y=900
scene.render.resolution_percentage=100
world=bpy.data.worlds.new("Review world");world.color=(.28,.27,.26);scene.world=world
light=bpy.data.lights.new("Large softbox",'AREA');light.energy=700
light.shape='DISK';light.size=4
lamp=bpy.data.objects.new("Large softbox",light);scene.collection.objects.link(lamp)
lamp.location=(2,-3,3)
lamp.rotation_euler=(Vector((0,0,.9))-lamp.location).to_track_quat('-Z','Y').to_euler()
camera_data=bpy.data.cameras.new("Review camera");camera_data.type='ORTHO'
camera_data.ortho_scale=2.15
camera=bpy.data.objects.new("Review camera",camera_data)
scene.collection.objects.link(camera);scene.camera=camera
for name,location in [("front",(0,-3,1.05)),("side",(3,0,1.05)),
                      ("back",(0,3,1.05)),("three_quarter",(2,-3,1.1))]:
    camera.location=location
    camera.rotation_euler=(Vector((0,0,.9))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/(name+".png"))
    bpy.ops.render.render(write_still=True)

manifest={"status":"FIRST_PASS_STATIC_VISUAL_STUDY_NOT_APPROVED",
          "source":str(source.relative_to(ROOT)),
          "source_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),
          "preview":str(preview.relative_to(ROOT)),
          "preview_sha256":hashlib.sha256(preview.read_bytes()).hexdigest(),
          "body_origin":"Independent MPFB human",
          "bone_count":len(rig.data.bones),"in_world":False,
          "story_role":"Arjun's love interest; later introduction"}
(OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
print("LEELA_BUILD",json.dumps(manifest))
