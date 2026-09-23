"""Build an independent, editable MPFB village-resident candidate.

Run with Blender 5.2 --background --python tools/characters/build_village_farmer.py.
Only bundled MPFB core assets and original procedural garments are used.
"""
import bpy
import bmesh
import hashlib
import json
import math
import struct
import sys
from pathlib import Path
from mathutils import Vector
from mathutils import Quaternion
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[2]
FEMALE = "--female" in sys.argv
SLUG = "village_woman" if FEMALE else "village_farmer"
OUT = ROOT / "WorkingAssets/NPCs" / SLUG
RUNTIME = ROOT / "characters/npcs" / (SLUG + ".glb")
DATA = Path.home() / "Library/Application Support/Blender/5.2/extensions/.user/blender_org/mpfb/data"
OUT.mkdir(parents=True, exist_ok=True)
RUNTIME.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
from bl_ext.blender_org.mpfb.services.humanservice import HumanService

macro = dict(gender=0.0 if FEMALE else 1.0, age=.63 if FEMALE else .67,
             muscle=.38 if FEMALE else .42, weight=.49 if FEMALE else .47, proportions=.5,
             height=.40 if FEMALE else .42, cupsize=.45, firmness=.5,
             race=dict(asian=.55, caucasian=.20, african=.25))
body = HumanService.create_human(macro_detail_dict=macro)
body.name = SLUG + "_MakeHuman_body"
body["source_workflow"] = "MPFB core basemesh; independent adult village NPC"
body["approval"] = "visual candidate, not owner approved"
print("BODY_BOUNDS", [(round(v, 3)) for v in body.dimensions])
rig = HumanService.add_builtin_rig(body, "game_engine", import_weights=True)
rig.name = SLUG + "_rig"

def mat(name, color, texture=None, rough=.85):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_fake_user = True
    m.diffuse_color = (*color, 1)
    bs = m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*color, 1)
    bs.inputs["Roughness"].default_value = rough
    if texture:
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(str(texture), check_existing=True)
        m.node_tree.links.new(t.outputs["Color"], bs.inputs["Base Color"])
    return m

skin_texture = (DATA / "skins/middleage_asian_female/middleage_lightskinned_female_diffuse2.png"
    if FEMALE else DATA / "skins/middleage_african_male/middleage_darkskinned_male_diffuse.png")
skin = mat("Warm brown skin - MPFB core", (.50, .39, .31), skin_texture, .68)
if FEMALE:
    bs = skin.node_tree.nodes.get("Principled BSDF")
    tex = next(n for n in skin.node_tree.nodes if n.type == 'TEX_IMAGE')
    mix = skin.node_tree.nodes.new('ShaderNodeMixRGB')
    mix.blend_type = 'MULTIPLY'
    mix.inputs[0].default_value = 1.0
    mix.inputs[2].default_value = (.60, .47, .36, 1.0)
    skin.node_tree.links.new(tex.outputs['Color'], mix.inputs[1])
    skin.node_tree.links.new(mix.outputs[0], bs.inputs['Base Color'])
body.data.materials.clear(); body.data.materials.append(skin)
for p in body.data.polygons:
    p.material_index = 0
    p.use_smooth = True
cotton = mat("Undyed handloom cotton", (.58, .53, .40))
hem = mat("Worn cotton edging", (.38, .32, .23))
dhoti_mat = mat("Faded indigo cotton dhoti", (.12, .17, .19))
hair_mat = mat("Dark hair", (.025, .019, .016))

eyes = HumanService.add_mhclo_asset(str(DATA / "eyes/low-poly/low-poly.mhclo"), body,
                                   asset_type="Eyes", subdiv_levels=0)
eyes.name = "Farmer_eyes"
hair_name = "braid01" if FEMALE else "short04"
hair = HumanService.add_mhclo_asset(str(DATA / "hair" / hair_name / (hair_name + ".mhclo")), body,
                                   asset_type="Hair", subdiv_levels=0)
hair.name = "Farmer_hair"
hair.data.materials.clear(); hair.data.materials.append(hair_mat)

# MPFB's fitted core garments supply shoulder, chest and sleeve topology. Keep
# only the upper connected component; the era-specific lower drapes are separate.
outfit_name = "female_casualsuit01" if FEMALE else "male_casualsuit03"
outfit = HumanService.add_mhclo_asset(str(DATA / "clothes" / outfit_name / (outfit_name + ".mhclo")),
                                     body, asset_type="Clothes", subdiv_levels=0)
outfit.name = "Fitted cotton upper base"
parent = list(range(len(outfit.data.vertices)))
def find(i):
    while parent[i] != i:
        parent[i] = parent[parent[i]]
        i = parent[i]
    return i
for edge in outfit.data.edges:
    parent[find(edge.vertices[0])] = find(edge.vertices[1])
top_height = {}
for vertex in outfit.data.vertices:
    root = find(vertex.index)
    top_height[root] = max(top_height.get(root, 0), vertex.co.z)
top_root = max(top_height, key=top_height.get)
top_group = outfit.vertex_groups.new(name="Period upper only")
top_group.add([v.index for v in outfit.data.vertices if find(v.index) == top_root], 1.0, 'REPLACE')
top_mask = outfit.modifiers.new("Keep fitted upper", 'MASK')
top_mask.vertex_group = top_group.name

for mod in body.modifiers:
    mod.show_viewport = mod.type == 'MASK'
bpy.context.view_layer.update()
source = bpy.data.meshes.new_from_object(body.evaluated_get(bpy.context.evaluated_depsgraph_get()))
group_id = body.vertex_groups["body"].index
ids = [v.index for v in source.vertices if any(g.group == group_id for g in v.groups)]
tree = KDTree(len(ids))
for i in ids:
    tree.insert(source.vertices[i].co, i)
tree.balance()
names = {g.index: g.name for g in body.vertex_groups}
bones = set(rig.data.bones.keys())
weights = {i: {names[g.group]: g.weight for g in source.vertices[i].groups
               if names[g.group] in bones} for i in ids}

def mesh(name, verts, faces, material, mode="body", native=False):
    if FEMALE and not native:
        verts = [(x * .88, y * .88, z * .90) for x, y, z in verts]
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces); data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    data.materials.append(material)
    for p in data.polygons: p.use_smooth = True
    bm = bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data); bm.free()
    for v in data.vertices:
        co = v.co
        if mode == "head":
            assignment = {"head": 1.0}
        elif mode == "chest":
            assignment = {"spine01": 1.0}
        elif mode == "leg":
            side = "l" if co.x > 0 else "r"
            assignment = {"thigh_" + side: .65, "calf_" + side: .35} if co.z < .7 else {"thigh_" + side: 1.0}
        elif mode == "torso":
            assignment = {"spine01": 1.0} if co.z > 1.2 else {"pelvis": 1.0}
        else:
            assignment = {}
            for _, i, dist in tree.find_n(co, 4):
                factor = 1 / max(.005, dist) ** 2
                for n, w in weights[i].items():
                    assignment[n] = assignment.get(n, 0) + w * factor
            total = sum(assignment.values())
            assignment = {n: w / total for n, w in assignment.items()} if total else {"pelvis": 1.0}
        for n, w in assignment.items():
            if w > .001:
                (obj.vertex_groups.get(n) or obj.vertex_groups.new(name=n)).add([v.index], w, 'REPLACE')
    obj.parent = rig
    arm = obj.modifiers.new("Rig", 'ARMATURE'); arm.object = rig
    return obj

def rings(name, levels, material, mode="body", sides=16, flutter=0):
    verts = []
    for row, (z, rx, ry, cx, cy) in enumerate(levels):
        for j in range(sides):
            a = j * math.tau / sides
            fold = 1 + flutter * math.cos(j * 5 * math.tau / sides + row * .7)
            verts.append((cx + math.cos(a) * rx * fold, cy + math.sin(a) * ry * fold, z))
    faces = []
    for r in range(len(levels)-1):
        for j in range(sides):
            k = (j + 1) % sides
            faces.append((r*sides+j, r*sides+k, (r+1)*sides+k, (r+1)*sides+j))
    return mesh(name, verts, faces, material, mode)

def sleeve(name, shoulder, wrist, radius_top, radius_end, material):
    # Cross-sections perpendicular to the sloping A-pose arm, with tapered cuff.
    verts=[]; sides=12
    for t, radius in [(0,radius_top),(.32,radius_top*.95),(.70,radius_end*1.05),(1,radius_end)]:
        center=Vector(shoulder).lerp(Vector(wrist),t)
        axis=(Vector(wrist)-Vector(shoulder)).normalized()
        across=Vector((axis.z,0,-axis.x)).normalized()
        for j in range(sides):
            a=j*math.tau/sides
            verts.append(tuple(center+radius*(math.cos(a)*across+math.sin(a)*Vector((0,1,0)))))
    faces=[(r*sides+j,r*sides+(j+1)%sides,(r+1)*sides+(j+1)%sides,(r+1)*sides+j)
           for r in range(3) for j in range(sides)]
    return mesh(name,verts,faces,material)

def fitted_blouse():
    keep={v.index for v in source.vertices if .88<v.co.z<1.29 and abs(v.co.x)<.235
          and any(g.group==group_id for g in v.groups)}
    faces=[list(p.vertices) for p in source.polygons if all(i in keep for i in p.vertices)]
    used=sorted({i for f in faces for i in f})
    lookup={i:j for j,i in enumerate(used)}
    verts=[source.vertices[i].co + source.vertices[i].normal*.012 for i in used]
    return mesh("Fitted everyday blouse",verts,[[lookup[i] for i in f] for f in faces],blouse,native=True)

def draped_pallu(material):
    verts = []
    across = 7
    along = 13
    for row in range(along):
        t = row / (along - 1)
        z = .91 + .35 * t
        center = -.10 + .19 * t
        width = .24 - .045 * t
        for col in range(across):
            u = col / (across - 1)
            x = center + (u - .5) * width
            # Smooth front drape over the fitted blouse. Ray hits change abruptly
            # across seams/arms and produced self-intersecting triangular cloth.
            surface_y = -.26 - .055 * math.sin(math.pi * t) + .015 * (abs(x) / .25) ** 2
            fold = .003 * math.sin(u * math.tau * 2 + t * 2.2)
            verts.append((x, surface_y - fold, z))
    faces = [(r*across+j, r*across+j+1, (r+1)*across+j+1, (r+1)*across+j)
             for r in range(along-1) for j in range(across-1)]
    return mesh("Woven sari pallu over blouse", verts, faces, material, mode="chest", native=True)

if FEMALE:
    # Patna-region 1800-1850 fruit-seller painting: sari over blouse, head drape.
    sari = mat("Faded madder cotton sari", (.36,.12,.10))
    border = mat("Indigo woven sari border", (.09,.12,.16))
    blouse = mat("Mustard cotton blouse", (.40,.30,.12))
    outfit.data.materials.clear(); outfit.data.materials.append(blouse)
    rings("Wrapped sari lower drape", [(.14,.30,.25,0,0),(.31,.31,.26,0,0),
          (.61,.29,.24,0,0),(.94,.245,.20,0,0),(1.08,.22,.18,0,0),
          (1.16,.205,.17,0,0)],
          sari, "torso", flutter=.055)
    rings("Sari lower border", [(.14,.303,.253,0,0),(.205,.31,.26,0,0)], border, "torso", flutter=.05)
    draped_pallu(sari)
else:
    # Cloth head wrap, loose kurta and dhoti, without martial clothing/equipment.
    outfit.data.materials.clear(); outfit.data.materials.append(cotton)
    turban = mat("Weathered ochre head cloth", (.40,.33,.23))
    dhoti_cotton = mat("Unbleached dhoti cotton", (.52,.49,.42))
    rings("Kurta loose lower panel", [(.66,.22,.18,0,0),(.72,.215,.18,0,0),
          (.85,.21,.175,0,0),(.92,.205,.17,0,0)], cotton, "torso", flutter=.04)
    rings("Knee length wrapped dhoti", [(.43,.25,.21,0,0),(.49,.255,.21,0,0),
          (.65,.23,.20,0,0),(.84,.20,.18,0,0)], dhoti_cotton, "torso", flutter=.08)
    rings("Dhoti woven border", [(.43,.252,.212,0,0),(.46,.254,.214,0,0)], hem, "torso", flutter=.08)
    rings("Soft cotton head wrap", [(1.54,.119,.11,0,0),(1.57,.13,.12,0,0),
           (1.60,.13,.12,0,0),(1.64,.10,.09,0,0),
           (1.675,.012,.012,0,0)], turban, "head", flutter=.025)
    rings("Head wrap fold", [(1.575,.132,.122,0,0),(1.59,.133,.123,0,0)], hem, "head")

# MPFB helper geometry must not leak into glTF; retain the source Blender file.
for side, sign in [("l", 1), ("r", -1)]:
    bone = rig.pose.bones.get("upperarm_" + side)
    if bone:
        axis = bone.bone.matrix_local.to_3x3().inverted() @ Vector((0, 1, 0))
        bone.rotation_mode = 'QUATERNION'
        bone.rotation_quaternion = Quaternion(axis, sign * math.radians(31))
rig.data.pose_position = 'POSE'
bpy.context.view_layer.update()
for mod in body.modifiers:
    if mod.type == 'MASK': mod.show_render = True
blend = OUT / (SLUG + "_mpfb.blend")
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.object.select_all(action='DESELECT')
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
depsgraph = bpy.context.evaluated_depsgraph_get()
static_meshes = []
for obj in meshes:
    evaluated = obj.evaluated_get(depsgraph)
    evaluated_mesh = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True,
                                                     depsgraph=depsgraph)
    static = bpy.data.objects.new(obj.name + "_static_preview", evaluated_mesh)
    bpy.context.scene.collection.objects.link(static)
    static.matrix_world = obj.matrix_world.copy()
    static.select_set(True)
    static_meshes.append(static)
bpy.context.view_layer.objects.active = static_meshes[0]
bpy.ops.export_scene.gltf(filepath=str(RUNTIME), export_format='GLB', use_selection=True,
    export_animations=False, export_cameras=False, export_lights=False,
    export_yup=True, export_skins=False, export_apply=False)
if FEMALE:
    # glTF's baseColorFactor multiplies the original CC0 MPFB skin texture on
    # the GPU; no source image is edited or duplicated.
    raw = RUNTIME.read_bytes()
    json_size = struct.unpack_from('<I', raw, 12)[0]
    document = json.loads(raw[20:20+json_size])
    for material in document['materials']:
        if material.get('name') == skin.name:
            material['pbrMetallicRoughness']['baseColorFactor'] = [.60, .47, .36, 1.0]
    packed = json.dumps(document, separators=(',', ':')).encode()
    packed += b' ' * ((-len(packed)) % 4)
    rest = raw[20+json_size:]
    RUNTIME.write_bytes(struct.pack('<4sII', b'glTF', 2, 20+len(packed)+len(rest))
                        + struct.pack('<I4s', len(packed), b'JSON') + packed + rest)
for static in static_meshes:
    static.hide_render = True
manifest = dict(status="CANDIDATE_NOT_APPROVED", source=str(blend.relative_to(ROOT)),
    source_sha256=hashlib.sha256(blend.read_bytes()).hexdigest(),
    runtime=str(RUNTIME.relative_to(ROOT)),
    runtime_sha256=hashlib.sha256(RUNTIME.read_bytes()).hexdigest(),
    mpfb_core_assets_license="CC0-1.0", bone_count=len(rig.data.bones),
    mesh_count=len(meshes), body_vertices=len(body.data.vertices))
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("NPC_BUILD", json.dumps(manifest))

# Review views use Eevee and are deliberately separate from runtime content.
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 720
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.world = bpy.data.worlds.new("Review world")
scene.world.color = (.28,.29,.27)
ld = bpy.data.lights.new("Review area light", 'AREA'); ld.energy = 650; ld.shape = 'DISK'; ld.size = 4
lo = bpy.data.objects.new("Review area light", ld); scene.collection.objects.link(lo)
lo.location = (1.8,-2.6,3.0)
lo.rotation_euler = (Vector((0,0,.9))-lo.location).to_track_quat('-Z','Y').to_euler()
cd = bpy.data.cameras.new("Review camera"); cd.type = 'ORTHO'; cd.ortho_scale = 2.15
cam = bpy.data.objects.new("Review camera", cd); scene.collection.objects.link(cam)
scene.camera = cam
for view, pos in [("front", (0,-3,1.05)), ("profile", (3,0,1.05))]:
    cam.location = pos
    cam.rotation_euler = (Vector((0,0,.86))-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath = str(OUT / (SLUG + "_" + view + ".png"))
    bpy.ops.render.render(write_still=True)
