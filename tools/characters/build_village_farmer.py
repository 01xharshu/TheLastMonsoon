"""Build an independent, editable MPFB village-resident candidate.

Run with Blender 5.2 --background --python tools/characters/build_village_farmer.py.
Only bundled MPFB core assets and original procedural garments are used.
"""
import bpy
import bmesh
import hashlib
import json
import math
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "WorkingAssets/NPCs/village_farmer"
RUNTIME = ROOT / "characters/npcs/village_farmer.glb"
DATA = Path.home() / "Library/Application Support/Blender/5.2/extensions/.user/blender_org/mpfb/data"
OUT.mkdir(parents=True, exist_ok=True)
RUNTIME.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
from bl_ext.blender_org.mpfb.services.humanservice import HumanService

macro = dict(gender=1.0, age=.67, muscle=.42, weight=.47, proportions=.5,
             height=.42, cupsize=.5, firmness=.5,
             race=dict(asian=.55, caucasian=.20, african=.25))
body = HumanService.create_human(macro_detail_dict=macro)
body.name = "Village_farmer_MakeHuman_body"
body["source_workflow"] = "MPFB core basemesh; independent adult village NPC"
body["approval"] = "visual candidate, not owner approved"
print("BODY_BOUNDS", [(round(v, 3)) for v in body.dimensions])
rig = HumanService.add_builtin_rig(body, "game_engine", import_weights=True)
rig.name = "Village_farmer_rig"

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
        mix = m.node_tree.nodes.new("ShaderNodeMixRGB")
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = .78
        mix.inputs[2].default_value = (*color, 1)
        m.node_tree.links.new(t.outputs["Color"], mix.inputs[1])
        m.node_tree.links.new(mix.outputs[0], bs.inputs["Base Color"])
    return m

skin = mat("Warm brown skin - MPFB core", (.55, .37, .25),
    DATA / "skins/middleage_asian_male/middleage_lightskinned_male_diffuse2.png", .68)
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
hair = HumanService.add_mhclo_asset(str(DATA / "hair/short04/short04.mhclo"), body,
                                   asset_type="Hair", subdiv_levels=0)
hair.name = "Farmer_hair"
hair.data.materials.clear(); hair.data.materials.append(hair_mat)

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

def mesh(name, verts, faces, material, mode="body"):
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

# Long village tunic, loose enough to clear the MPFB torso. The split lower hem
# and separate dhoti leg wraps allow later walking motion without a solid skirt.
rings("Handloom long kurta", [(.81,.31,.23,0,0),(.88,.30,.22,0,0),
    (1.04,.27,.21,0,0),(1.24,.25,.19,0,0),(1.44,.27,.18,0,0),
    (1.53,.19,.14,0,0)], cotton, "torso", flutter=.045)
rings("Kurta collar", [(1.505,.16,.125,0,0),(1.55,.14,.115,0,0)], hem, "torso")
for s in [-1, 1]:
    rings("Dhoti drape " + str(s), [(.14,.125,.115,s*.13,0),(.35,.16,.15,s*.13,0),
          (.63,.17,.16,s*.13,0),(.86,.20,.18,s*.11,0)], dhoti_mat, "leg", flutter=.035)
    rings("Kurta loose sleeve " + str(s), [(.94,.115,.10,s*.53,0),
          (1.10,.13,.11,s*.44,0),(1.31,.14,.12,s*.33,0),
          (1.44,.15,.13,s*.26,0)], cotton, "body")
    rings("Sleeve cuff " + str(s), [(.94,.118,.102,s*.53,0),(.975,.12,.104,s*.52,0)], hem, "body")
rings("Soft cotton head wrap", [(1.64,.128,.12,0,0),(1.69,.16,.14,0,0),
       (1.735,.17,.145,0,0),(1.78,.15,.13,0,0)], dhoti_mat, "head", flutter=.025)
rings("Head wrap fold", [(1.735,.171,.147,0,0),(1.75,.17,.146,0,0)], cotton, "head")

# MPFB helper geometry must not leak into glTF; retain the source Blender file.
for mod in body.modifiers:
    if mod.type == 'MASK': mod.show_render = True
blend = OUT / "village_farmer_mpfb.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o != body or o == body]
for obj in meshes: obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(RUNTIME), export_format='GLB', use_selection=True,
    export_animations=False, export_cameras=False, export_lights=False,
    export_yup=True, export_skins=True, export_apply=False)
manifest = dict(status="CANDIDATE_NOT_APPROVED", source=str(blend.relative_to(ROOT)),
    source_sha256=hashlib.sha256(blend.read_bytes()).hexdigest(),
    runtime=str(RUNTIME.relative_to(ROOT)),
    runtime_sha256=hashlib.sha256(RUNTIME.read_bytes()).hexdigest(),
    mpfb_core_assets_license="CC0-1.0", bone_count=len(rig.data.bones),
    mesh_count=len(meshes), body_vertices=len(body.data.vertices))
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("NPC_BUILD", json.dumps(manifest))
