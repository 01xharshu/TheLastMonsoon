"""Build one additional editable British NPC pair from its multiview study.

Run: Blender --background --python tools/characters/build_british_roster_pair.py -- corporal
No runtime export or approval is implied by this candidate builder.
"""
import bpy
import bmesh
import math
import json
import hashlib
import sys
from pathlib import Path
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[2]
RANK = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else 'corporal'
CONFIGS = {
    'corporal': {'age':.36,'height':.51,'weight':.46,'woman_age':.33,'woman_weight':.51,'man_hair':'short03','woman_hair':'braid01','coat':(.45,.052,.039),'trouser':(.060,.066,.075),'dress':(.56,.39,.20),'skirt':(.61,.44,.23),'hat':True,'chevrons':2,'class':'working'},
    'sergeant': {'age':.55,'height':.56,'weight':.54,'woman_age':.43,'woman_weight':.48,'man_hair':'short04','woman_hair':'bob01','coat':(.40,.045,.035),'trouser':(.064,.073,.085),'dress':(.37,.44,.50),'skirt':(.40,.47,.53),'hat':True,'chevrons':3,'class':'working'},
    'lieutenant': {'age':.30,'height':.57,'weight':.44,'woman_age':.32,'woman_weight':.45,'man_hair':'short01','woman_hair':'braid01','coat':(.48,.057,.047),'trouser':(.15,.17,.19),'dress':(.60,.69,.75),'skirt':(.63,.72,.77),'hat':False,'chevrons':0,'class':'gentry'},
    'captain': {'age':.42,'height':.60,'weight':.50,'woman_age':.37,'woman_weight':.48,'man_hair':'short03','woman_hair':'bob02','coat':(.43,.046,.035),'trouser':(.12,.14,.17),'dress':(.62,.66,.55),'skirt':(.76,.73,.64),'hat':False,'chevrons':0,'class':'gentry'},
    'major': {'age':.60,'height':.56,'weight':.57,'woman_age':.51,'woman_weight':.53,'man_hair':'short04','woman_hair':'braid01','coat':(.38,.041,.032),'trouser':(.11,.13,.16),'dress':(.16,.29,.22),'skirt':(.18,.32,.24),'hat':False,'chevrons':0,'class':'gentry'},
    'colonel': {'age':.72,'height':.58,'weight':.59,'woman_age':.57,'woman_weight':.51,'man_hair':'short01','woman_hair':'bob01','coat':(.39,.042,.033),'trouser':(.10,.12,.15),'dress':(.37,.085,.12),'skirt':(.40,.095,.13),'hat':False,'chevrons':0,'class':'gentry'},
    'official': {'age':.63,'height':.54,'weight':.56,'woman_age':.54,'woman_weight':.50,'man_hair':'short03','woman_hair':'bob02','coat':(.65,.61,.50),'trouser':(.27,.25,.23),'dress':(.58,.51,.65),'skirt':(.61,.54,.68),'hat':False,'chevrons':0,'class':'civil'},
}
if RANK not in CONFIGS:
    raise ValueError(f'Unknown British NPC rank/post: {RANK}')
CFG = CONFIGS[RANK]
OUT = ROOT / f"WorkingAssets/NPCs/british/{RANK}_pair"
REVIEW = ROOT / "docs/characters/british/candidates"
DATA = Path.home() / "Library/Application Support/Blender/5.2/extensions/.user/blender_org/mpfb/data"
OUT.mkdir(parents=True, exist_ok=True)
REVIEW.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
from bl_ext.blender_org.mpfb.services.humanservice import HumanService

def material(name, rgb, texture=None):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*rgb, 1)
    bs.inputs["Roughness"].default_value = .82
    if texture and texture.exists():
        image = m.node_tree.nodes.new("ShaderNodeTexImage")
        image.image = bpy.data.images.load(str(texture), check_existing=True)
        m.node_tree.links.new(image.outputs["Color"], bs.inputs["Base Color"])
    return m

def fabric_grain(mat, light, dark, scale=65):
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bs = nodes.get('Principled BSDF')
    coord = nodes.new('ShaderNodeTexCoord')
    noise = nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = scale
    noise.inputs['Detail'].default_value = 2
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = .27
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].position = .72
    ramp.color_ramp.elements[1].color = (*light, 1)
    bump = nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = .035
    bump.inputs['Distance'].default_value = .002
    links.new(coord.outputs['Generated'], noise.inputs['Vector'])
    links.new(noise.outputs['Fac'], ramp.inputs['Fac'])
    links.new(ramp.outputs['Color'], bs.inputs['Base Color'])
    links.new(noise.outputs['Fac'], bump.inputs['Height'])
    links.new(bump.outputs['Normal'], bs.inputs['Normal'])

def make_mesh(name, verts, faces, mat, rig, tree, weight_map, mode="nearest"):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    data.materials.append(mat)
    bm = bmesh.new(); bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data); bm.free()
    for polygon in data.polygons:
        polygon.use_smooth = True
    for vertex in data.vertices:
        if mode == "head":
            weights = {"head": 1.0}
        elif mode == "pelvis":
            weights = {"pelvis": 1.0}
        else:
            weights = {}
            for _, index, distance in tree.find_n(vertex.co, 4):
                factor = 1 / max(distance, .01) ** 2
                for bone, value in weight_map[index].items():
                    weights[bone] = weights.get(bone, 0) + value * factor
            total = sum(weights.values())
            weights = {name: value / total for name, value in weights.items()} if total else {"pelvis": 1.0}
        for bone, value in weights.items():
            if value > .001:
                (obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)).add([vertex.index], value, "REPLACE")
    obj.parent = rig
    obj.modifiers.new("Armature deformation", "ARMATURE").object = rig
    return obj

def rings(name, levels, mat, rig, tree, weights, mode="nearest", sides=24, folds=0):
    verts=[]
    for row, (z, rx, ry, cx, cy) in enumerate(levels):
        for j in range(sides):
            angle = math.tau * j / sides
            ripple = 1 + folds * math.cos(angle * 7 + row * .3)
            verts.append((cx + rx * ripple * math.cos(angle), cy + ry * ripple * math.sin(angle), z))
    faces=[]
    for row in range(len(levels)-1):
        for j in range(sides):
            nxt=(j+1)%sides
            faces.append((row*sides+j,row*sides+nxt,(row+1)*sides+nxt,(row+1)*sides+j))
    return make_mesh(name,verts,faces,mat,rig,tree,weights,mode)

def gathered_skirt(name, mat, rig, tree, weights, fullness=1, scale=1):
    levels = []
    for row in range(25):
        t = row / 24
        z = (.82 - .75 * t) * scale
        bell = math.sin(t * math.pi / 2) ** 1.35
        r = (.215 + .265 * fullness * bell) * scale
        levels.append((z, r, r * .92, 0, 0))
    return rings(name, levels, mat, rig, tree, weights, 'pelvis', sides=72, folds=.065)

def cloth_strip(name, path, width, mat, rig, tree, weights, front=True, scale=1):
    verts=[]
    for x,z in path:
        for xx in (x-width/2,x+width/2):
            y=scale*(-.17-.10*(1.43-z/scale)) if front else .115*scale
            verts.append((xx,y,z))
    faces=[(i*2,i*2+1,i*2+3,i*2+2) for i in range(len(path)-1)]
    obj=make_mesh(name,verts,faces,mat,rig,tree,weights)
    solid=obj.modifiers.new('Leather thickness','SOLIDIFY')
    solid.thickness=.003
    return obj

def accessory_box(name, location, dimensions, mat, rig, bone, bevel=.008):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj=bpy.context.object
    obj.name=name
    obj.dimensions=dimensions
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(mat)
    obj.parent=rig
    obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))),1,'REPLACE')
    obj.modifiers.new('Armature deformation','ARMATURE').object=rig
    if bevel:
        mod=obj.modifiers.new('Soft edges','BEVEL')
        mod.width=bevel
        mod.segments=2
        obj.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return obj

def create_person(slug, female, macro, skin_path, hair_name):
    body = HumanService.create_human(macro_detail_dict=macro)
    body.name = slug + "_MPFB_body"
    body["source_workflow"] = "MakeHuman MPFB core body; isolated British NPC candidate"
    body["approval"] = "candidate only; costume, motion, and historical detail unapproved"
    rig = HumanService.add_builtin_rig(body,"game_engine",import_weights=True)
    rig.name = slug + "_game_engine_rig"
    skin = material(slug+" skin",(.72,.54,.43),skin_path)
    body.data.materials.clear();body.data.materials.append(skin)
    for poly in body.data.polygons: poly.material_index=0;poly.use_smooth=True
    eyes = HumanService.add_mhclo_asset(str(DATA/"eyes/low-poly/low-poly.mhclo"),body,asset_type="Eyes",subdiv_levels=0)
    eyes.name=slug+"_eyes"
    hair = HumanService.add_mhclo_asset(str(DATA/f"hair/{hair_name}/{hair_name}.mhclo"),body,asset_type="Hair",subdiv_levels=0)
    hair.name=slug+"_hair"
    hair.data.materials.clear();hair.data.materials.append(material(slug+" brown hair",(.13,.085,.055)))
    shoe_slug = "shoes03" if female else "shoes04"
    shoes = HumanService.add_mhclo_asset(str(DATA/f"clothes/{shoe_slug}/{shoe_slug}.mhclo"),body,asset_type="Clothes",subdiv_levels=0)
    shoes.name = slug + "_shoes"
    shoes.data.materials.clear();shoes.data.materials.append(material(slug+" dark leather shoes",(.045,.037,.033)))
    outfit_slug = "female_elegantsuit01" if female else ("male_elegantsuit01" if RANK == 'official' else "male_casualsuit03")
    outfit = HumanService.add_mhclo_asset(str(DATA/f"clothes/{outfit_slug}/{outfit_slug}.mhclo"),body,asset_type="Clothes",subdiv_levels=0)
    outfit.name = slug + "_fitted_cloth_base"
    for mod in body.modifiers: mod.show_viewport = mod.type == "MASK"
    bpy.context.view_layer.update()
    source=bpy.data.meshes.new_from_object(body.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    body_group=body.vertex_groups["body"].index
    indices=[v.index for v in source.vertices if any(g.group==body_group for g in v.groups)]
    tree=KDTree(len(indices))
    for index in indices: tree.insert(source.vertices[index].co,index)
    tree.balance()
    names={group.index:group.name for group in body.vertex_groups}
    bone_names=set(rig.data.bones.keys())
    weights={index:{names[group.group]:group.weight for group in source.vertices[index].groups if names[group.group] in bone_names} for index in indices}
    bpy.data.meshes.remove(source)
    return body,rig,tree,weights,outfit

male_macro=dict(gender=1.0,age=CFG['age'],muscle=.40,weight=CFG['weight'],proportions=.5,height=CFG['height'],cupsize=.5,firmness=.5,race=dict(asian=.02,caucasian=.96,african=.02))
female_macro=dict(gender=0.0,age=CFG['woman_age'],muscle=.34,weight=CFG['woman_weight'],proportions=.5,height=.46,cupsize=.5,firmness=.5,race=dict(asian=.02,caucasian=.96,african=.02))
male_skin_name='old' if CFG['age']>.67 else ('young' if CFG['age']<.34 else 'middleage')
female_skin_name='old' if CFG['woman_age']>.55 else ('young' if CFG['woman_age']<.36 else 'middleage')
male_skin=DATA/f"skins/{male_skin_name}_caucasian_male/{male_skin_name}_lightskinned_male_diffuse.png"
female_skin=DATA/f"skins/{female_skin_name}_caucasian_female/{female_skin_name}_lightskinned_female_diffuse.png"
body,rig,tree,weights,male_outfit=create_person(RANK.capitalize(),False,male_macro,male_skin,CFG['man_hair'])
woman,wr,wt,ww,female_outfit=create_person("Companion",True,female_macro,female_skin,CFG['woman_hair'])
# MPFB creation clears orphan data blocks, so keep costume materials until both
# bodies and their assets have been constructed.
red=material(f"{RANK} coat study wool",CFG['coat'])
dark=material(f"{RANK} trouser study wool",CFG['trouser'])
white=material("Study - white leather",(.76,.72,.61))
black=material("Study - black leather",(.035,.029,.025))
cotton=material(f"{RANK} companion bodice cotton",CFG['dress'])
skirt_color=material(f"{RANK} companion skirt cotton",CFG['skirt'])
trim=material("Study - muted blue trim",(.27,.34,.37))
brass=material("Study - aged brass",(.47,.35,.15))
def lighter(c, factor):
    return tuple(min(1,x*factor) for x in c)
for mat, light, shade, scale in [(red,lighter(CFG['coat'],1.07),lighter(CFG['coat'],.93),140),(dark,lighter(CFG['trouser'],1.08),lighter(CFG['trouser'],.94),135),(cotton,lighter(CFG['dress'],1.05),lighter(CFG['dress'],.95),175),(skirt_color,lighter(CFG['skirt'],1.05),lighter(CFG['skirt'],.95),175)]:
    fabric_grain(mat, light, shade, scale)

def recolor_outfit(obj, upper, lower):
    obj.data.materials.clear()
    obj.data.materials.append(upper)
    obj.data.materials.append(lower)
    parent = list(range(len(obj.data.vertices)))
    def find(index):
        while parent[index] != index:
            parent[index] = parent[parent[index]]
            index = parent[index]
        return index
    for edge in obj.data.edges:
        a, b = find(edge.vertices[0]), find(edge.vertices[1])
        parent[a] = b
    highest = {}
    for vertex in obj.data.vertices:
        root = find(vertex.index)
        highest[root] = max(highest.get(root, -1), vertex.co.z)
    for poly in obj.data.polygons:
        poly.material_index = 0 if highest[find(poly.vertices[0])] > 1.2 else 1
        poly.use_smooth = True
    solidify = obj.modifiers.new("Cloth shell", 'SOLIDIFY')
    solidify.thickness = .005
    solidify.offset = 1

recolor_outfit(male_outfit,red,dark)
recolor_outfit(female_outfit,cotton,cotton)
male_scale=max(c[2] for c in body.bound_box)/1.74
female_scale=max(c[2] for c in woman.bound_box)/1.47
def scaled_levels(levels, scale):
    return [(z*scale,rx*scale,ry*scale,cx*scale,cy*scale) for z,rx,ry,cx,cy in levels]
if RANK == 'official':
    rings("Official dark top hat",scaled_levels([(1.66,.17,.15,0,0),(1.685,.18,.16,0,0),(1.70,.13,.12,0,0),(1.99,.13,.12,0,0),(2.00,.005,.005,0,0)],male_scale),black,rig,tree,weights,'head')
else:
    rings(f"{RANK} forage cap",scaled_levels([(1.67,.175,.17,0,0),(1.70,.18,.175,0,0),(1.76,.17,.16,0,0),(1.78,.10,.10,0,0),(1.785,.005,.005,0,0)],male_scale),dark,rig,tree,weights,"head")
    rings(f"{RANK} cap band",scaled_levels([(1.685,.182,.177,0,0),(1.70,.182,.177,0,0)],male_scale),red,rig,tree,weights,"head")
    accessory_box(f"{RANK} forage cap visor",(0,-.175*male_scale,1.674*male_scale),(.26*male_scale,.14*male_scale,.015*male_scale),black,rig,'head',.015*male_scale)
if RANK in ('corporal','sergeant'):
    for side in (-1,1):
        path=[(side*(.18-.36*t)*male_scale,(1.43-.34*t)*male_scale) for t in (i/28 for i in range(29))]
        cloth_strip(f"{RANK} front crossbelt {side}",path,.053*male_scale,white,rig,tree,weights,scale=male_scale)
        cloth_strip(f"{RANK} back crossbelt {side}",path,.053*male_scale,white,rig,tree,weights,front=False,scale=male_scale)
for z in (1.15,1.23,1.31,1.39):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=.009*male_scale, location=(0,-.196*male_scale,z*male_scale))
    button=bpy.context.object
    button.name=f"{RANK} brass coat button {z:.2f}"
    button.data.materials.append(brass)
    button.parent=rig
    button.vertex_groups.new(name='spine_02').add(list(range(len(button.data.vertices))),1,'REPLACE')
    button.modifiers.new('Armature deformation','ARMATURE').object=rig

if CFG['chevrons']:
    for side in (-1,1):
        x=side*.315*male_scale
        for stripe in range(CFG['chevrons']):
            z=(1.20-stripe*.035)*male_scale
            a=.052*male_scale; y=-.115*male_scale; h=.020*male_scale
            verts=[(x-a,y,z+h),(x,y,z-h),(x+a,y,z+h),(x+a,y,z+h+.013*male_scale),(x,y,z-h+.013*male_scale),(x-a,y,z+h+.013*male_scale)]
            make_mesh(f"{RANK} sleeve chevron {side} {stripe+1}",verts,[(0,1,4,5),(1,2,3,4)],white,rig,tree,weights)
elif CFG['class']=='gentry':
    for side in (-1,1):
        accessory_box(f"{RANK} officer shoulder trim {side}",(side*.23*male_scale,-.01*male_scale,1.45*male_scale),(.12*male_scale,.085*male_scale,.018*male_scale),brass,rig,'spine_02',.004)
    accessory_box(f"{RANK} sword study blade",(.32*male_scale,-.02,.62*male_scale),(.018,.026,.57*male_scale),white,rig,'pelvis',.003)
    accessory_box(f"{RANK} sword study hilt",(.32*male_scale,-.02,.92*male_scale),(.065,.04,.035),brass,rig,'pelvis',.006)

# The MPFB adult body stays intact beneath separate opaque study garments.
gathered_skirt("Companion gathered skirt",skirt_color,wr,wt,ww,1.0 if CFG['class']=='working' else 1.23,female_scale)
if CFG['hat']:
    rings("Companion bonnet crown",scaled_levels([(1.43,.14,.13,0,.04),(1.49,.16,.15,0,.04),(1.55,.12,.12,0,.04),(1.575,.005,.005,0,.04)],female_scale),trim,wr,wt,ww,"head")
    rings("Companion bonnet brim",scaled_levels([(1.43,.17,.15,0,-.025),(1.45,.18,.16,0,-.025)],female_scale),cotton,wr,wt,ww,"head")

source_path=OUT/f"{RANK}_pair_mpfb_candidate.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(source_path))
manifest={"status":"CANDIDATE_NOT_APPROVED","pair":RANK,"source":str(source_path.relative_to(ROOT)),"source_sha256":hashlib.sha256(source_path.read_bytes()).hexdigest(),"reference":f"docs/characters/british/references/{RANK}_and_companion_multiview.png","male_body_vertices":len(body.data.vertices),"female_body_vertices":len(woman.data.vertices),"male_bones":len(rig.data.bones),"female_bones":len(wr.data.bones),"mpfb_data":str(DATA),"runtime_export":False,"visual_approved":False,"motion_approved":False,"costume_status":"study geometry; historically unverified"}
(REVIEW/f"{RANK}_pair_manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
print("BRITISH_ROSTER_PAIR",json.dumps(manifest))
