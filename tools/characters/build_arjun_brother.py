"""Create an independent MakeHuman/MPFB sepoy candidate for Dev, Arjun's brother."""
import bpy
import hashlib
import json
import math
from pathlib import Path
from mathutils import Vector, Quaternion
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "WorkingAssets/NPCs/arjun_brother"
DATA = Path.home() / "Library/Application Support/Blender/5.2/extensions/.user/blender_org/mpfb/data"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
from bl_ext.blender_org.mpfb.services.humanservice import HumanService

body = HumanService.create_human(macro_detail_dict=dict(
    gender=1.0, age=.56, muscle=.59, weight=.48, proportions=.50, height=.48,
    cupsize=.5, firmness=.5, race=dict(asian=.55, caucasian=.20, african=.25)))
body.name = "Arjun_brother_independent_MakeHuman_body"
body["role"] = "Dev; Arjun's older brother; sepoy; story character candidate"
body["source"] = "Independent MPFB basemesh; no Arjun mesh or rejected appearance reused"
body["age_years"] = 29
rig = HumanService.add_builtin_rig(body, "game_engine", import_weights=True)
rig.name = "Brother_game_engine_rig"

def mat(name, color, texture=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_fake_user = True
    m.diffuse_color = (*color, 1)
    bs = m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*color, 1)
    bs.inputs["Roughness"].default_value = .84
    if "coat" in name.lower() or "cotton" in name.lower():
        noise = m.node_tree.nodes.new('ShaderNodeTexNoise')
        noise.inputs['Scale'].default_value = 180
        noise.inputs['Detail'].default_value = 2
        bump = m.node_tree.nodes.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value = .12
        bump.inputs['Distance'].default_value = .00035
        m.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height'])
        m.node_tree.links.new(bump.outputs['Normal'],bs.inputs['Normal'])
    if texture:
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(str(texture), check_existing=True)
        m.node_tree.links.new(tex.outputs["Color"], bs.inputs["Base Color"])
    return m

skin = mat("Warm brown skin", (.48,.34,.24), DATA / "skins/middleage_african_male/middleage_darkskinned_male_diffuse.png")
body.data.materials.clear(); body.data.materials.append(skin)
for face in body.data.polygons: face.use_smooth = True
dark = mat("Dark hair", (.025,.019,.016))
coat = mat("Faded red sepoy coat candidate", (.18,.025,.022))
trim = mat("Muted brass trim", (.56,.39,.15))
cotton = mat("Off-white cotton trousers", (.65,.61,.49))
leather = mat("Brown leather", (.16,.085,.045))

eyes = HumanService.add_mhclo_asset(str(DATA / "eyes/low-poly/low-poly.mhclo"), body, asset_type="Eyes", subdiv_levels=0)
eyes.name = "Brother_eyes"
hair = HumanService.add_mhclo_asset(str(DATA / "hair/short04/short04.mhclo"), body, asset_type="Hair", subdiv_levels=0)
hair.name = "Brother_short_hair"
hair.data.materials.clear(); hair.data.materials.append(dark)

# MPFB's fitted upper has a continuous torso, shoulders and sleeves. Keep its
# upper component and replace the modern trouser component with period layers.
outfit_name = "male_casualsuit03"
outfit = HumanService.add_mhclo_asset(str(DATA / "clothes" / outfit_name / (outfit_name + ".mhclo")),
                                     body, asset_type="Clothes", subdiv_levels=0)
outfit.name = "Dev_fitted_uniform_upper"
outfit.data.materials.clear(); outfit.data.materials.append(coat)
parents = list(range(len(outfit.data.vertices)))
def find(index):
    while parents[index] != index:
        parents[index] = parents[parents[index]]
        index = parents[index]
    return index
for edge in outfit.data.edges:
    parents[find(edge.vertices[0])] = find(edge.vertices[1])
height_by_component = {}
for vertex in outfit.data.vertices:
    component = find(vertex.index)
    height_by_component[component] = max(height_by_component.get(component, 0), vertex.co.z)
upper_component = max(height_by_component, key=height_by_component.get)
upper_group = outfit.vertex_groups.new(name="Fitted upper only")
upper_group.add([v.index for v in outfit.data.vertices if find(v.index)==upper_component
    ], 1, 'REPLACE')
outfit_mask = outfit.modifiers.new("Keep fitted upper", 'MASK')
outfit_mask.vertex_group = upper_group.name

def attach(name, vertices, faces, material, bone):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces); mesh.update()
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for p in mesh.polygons: p.use_smooth = True
    obj.parent = rig
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(vertices))), 1, 'REPLACE')
    mod = obj.modifiers.new("Rig", 'ARMATURE'); mod.object = rig
    return obj

def rings(name, levels, material, bone="spine01", sides=20):
    vertices = []
    for z, rx, ry, cx, cy in levels:
        vertices += [(cx+rx*math.cos(i*math.tau/sides), cy+ry*math.sin(i*math.tau/sides), z) for i in range(sides)]
    faces = [(r*sides+i, r*sides+(i+1)%sides, (r+1)*sides+(i+1)%sides, (r+1)*sides+i)
             for r in range(len(levels)-1) for i in range(sides)]
    return attach(name, vertices, faces, material, bone)

def tube(name, start, end, radius_a, radius_b, material, bone, sides=12):
    a,b=Vector(start),Vector(end)
    axis=(b-a).normalized()
    u=axis.cross(Vector((0,1,0))).normalized()
    v=axis.cross(u).normalized()
    vertices=[tuple(center + radius*(math.cos(i*math.tau/sides)*u+math.sin(i*math.tau/sides)*v))
              for center,radius in [(a,radius_a),(b,radius_b)] for i in range(sides)]
    return attach(name, vertices, [(i,(i+1)%sides,sides+(i+1)%sides,sides+i) for i in range(sides)], material, bone)

# Costume is a readable first design study. Unit-specific tailoring and insignia
# remain deliberately unresolved until the story fixes his regiment and year.
skirt = rings("Coat lower skirts", [(.76,.245,.19,0,0),(.80,.24,.182,0,0),
    (.84,.234,.175,0,0),(.90,.22,.166,0,0),(.96,.205,.16,0,0),(1.055,.155,.125,0,0)], coat, sides=40)
for vertex in skirt.data.vertices:
    angle = math.atan2(vertex.co.y,vertex.co.x)
    fold = .0035*math.cos(angle*8)*(1.055-vertex.co.z)/.295
    vertex.co.x += math.cos(angle)*fold
    vertex.co.y += math.sin(angle)*fold
waist_leather = mat("Dark leather waist belt",(.045,.022,.012))
rings("Coat waist seam", [(.96,.212,.166,0,0),(.988,.212,.166,0,0)], waist_leather, sides=40)
rings("Uniform standing collar",[(1.405,.105,.081,0,0),(1.435,.103,.079,0,0),
    (1.465,.095,.074,0,0)],coat,"spine03",sides=40)
for side,sign in [("left",1),("right",-1)]:
    suffix = "l" if sign == 1 else "r"
    thigh = rig.data.bones["thigh_" + suffix]
    calf = rig.data.bones["calf_" + suffix]
    levels = []
    for z in [.09,.14,.20,.30,.42,.47,.52,.57,.68,.84]:
        bone = calf if z < calf.head_local.z else thigh
        t = (z-bone.head_local.z)/(bone.tail_local.z-bone.head_local.z)
        center = bone.head_local.lerp(bone.tail_local,t)
        radius = .077 + .041 * (z-.09)/.75
        levels.append((z,radius,radius,center.x,center.y))
    trousers = rings(side+" trouser",levels,cotton,"thigh_"+suffix)
    trousers.vertex_groups.clear()
    for vertex in trousers.data.vertices:
        upper = max(0,min(1,(vertex.co.z-.43)/.13))
        for name,weight in [("thigh_"+suffix,upper),("calf_"+suffix,1-upper)]:
            if weight > 0:
                (trousers.vertex_groups.get(name) or trousers.vertex_groups.new(name=name)).add([vertex.index],weight,'REPLACE')
boots = HumanService.add_mhclo_asset(str(DATA / "clothes/shoes03/shoes03.mhclo"),
    body,asset_type="Clothes",subdiv_levels=0)
boots.name = "Dev_fitted_boots"
boot_leather = mat("Worn dark boot leather",(.055,.035,.022),DATA / "clothes/shoes03/shoes03_diffuse.png")
boots.data.materials.clear();boots.data.materials.append(boot_leather)
for polygon in boots.data.polygons: polygon.use_smooth = True
# Sample the actual garment surface so trim sits against the fitted coat.
bpy.context.view_layer.update()
garment_trees = []
deps = bpy.context.evaluated_depsgraph_get()
for garment in [outfit,skirt]:
    evaluated = garment.evaluated_get(deps)
    mesh = evaluated.to_mesh()
    garment_trees.append(BVHTree.FromPolygons([v.co for v in mesh.vertices],
        [list(p.vertices) for p in mesh.polygons]))
    evaluated.to_mesh_clear()
def front_y(x,z):
    hits = [tree.ray_cast(Vector((x,-1,z)),Vector((0,1,0)),2)[0] for tree in garment_trees]
    values = [hit.y for hit in hits if hit is not None]
    return min(values)-.005 if values else -.15
def fitted_strip(name,start,end,width,material):
    vertices=[]
    for i in range(18):
        t=i/17
        x=start[0]*(1-t)+end[0]*t
        z=start[1]*(1-t)+end[1]*t
        for dx in [-width/2,width/2]:
            vertices.append((x+dx,front_y(x+dx,z),z))
    return attach(name,vertices,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(17)],material,"spine01")
fitted_strip("Crossbody leather webbing",(-.18,1.34),(.14,.91),.038,leather)
fitted_strip("Coat front placket",(0,.87),(0,1.36),.03,coat)
for i in range(6):
    z=1.01+i*.065
    y=front_y(.012,z)-.003
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,location=(.012,y,z))
    button=bpy.context.object;button.name="Coat brass button %d"%(i+1)
    button.scale=(.011,.006,.011);button.data.materials.append(trim)
    button.parent=rig
    group=button.vertex_groups.new(name="spine01")
    group.add(list(range(len(button.data.vertices))),1,'REPLACE')
    button.modifiers.new("Rig",'ARMATURE').object=rig
# The short hair keeps the face visible in this first family-likeness study.

# Hide the basemesh under cloth while retaining editable source geometry.
visible=body.vertex_groups.new(name="Visible skin")
indices=[v.index for v in body.data.vertices if v.co.z>1.43 or
         (abs(v.co.x)>.36 and .86<v.co.z<1.37)]
visible.add(indices,1,'REPLACE')
mask=body.modifiers.new("Hide clothed skin",'MASK'); mask.vertex_group=visible.name
for mod in body.modifiers:
    if mod.name.startswith("Delete."): mod.show_viewport=False; mod.show_render=False

# Relax the imported A-pose for the review source and the idle's base pose.
# Retain the underlying game-engine rig and weighted garment for later clips.
for side, sign in [("l", 1), ("r", -1)]:
    bone = rig.pose.bones.get("upperarm_" + side)
    if bone:
        axis = bone.bone.matrix_local.to_3x3().inverted() @ Vector((0, 1, 0))
        bone.rotation_mode = 'QUATERNION'
        bone.rotation_quaternion = Quaternion(axis, sign * math.radians(28))
rig.data.pose_position = 'POSE'
for bone in rig.pose.bones:
    if bone.name.startswith(('index_','middle_','ring_','pinky_')):
        bone.rotation_mode = 'QUATERNION'
        bone.rotation_quaternion = Quaternion((1,0,0),.25 if '_01_' in bone.name else .18)

blend=OUT/"arjun_brother_mpfb.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
# Bake a static review GLB. Editable rig and body remain in the Blend source.
bpy.context.view_layer.update()
deps=bpy.context.evaluated_depsgraph_get()
for obj in list(bpy.data.objects):
    if obj.type!='MESH': continue
    baked=bpy.data.meshes.new_from_object(obj.evaluated_get(deps), preserve_all_data_layers=True, depsgraph=deps)
    copy=bpy.data.objects.new(obj.name+"_preview",baked)
    bpy.context.scene.collection.objects.link(copy)
    copy.matrix_world=obj.matrix_world.copy()
    obj.hide_render=True
    obj.select_set(False)
    copy.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/"arjun_brother_preview.glb"),export_format='GLB',use_selection=True,
    export_animations=False,export_cameras=False,export_lights=False,export_skins=False)

scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=720;scene.render.resolution_y=900;scene.render.resolution_percentage=100
world=bpy.data.worlds.new("Review world");world.color=(.24,.25,.27);scene.world=world
light=bpy.data.lights.new("Large softbox",'AREA');light.energy=700;light.shape='DISK';light.size=4
lamp=bpy.data.objects.new("Large softbox",light);scene.collection.objects.link(lamp)
lamp.location=(2,-3,3)
lamp.rotation_euler=(Vector((0,0,.9))-lamp.location).to_track_quat('-Z','Y').to_euler()
camdata=bpy.data.cameras.new("Review camera");camdata.type='ORTHO';camdata.ortho_scale=2.15
cam=bpy.data.objects.new("Review camera",camdata);scene.collection.objects.link(cam);scene.camera=cam
for name,loc in [("front",(0,-3,1.05)),("profile",(3,0,1.05)),("three_quarter",(2,-3,1.1))]:
    cam.location=loc
    cam.rotation_euler=(Vector((0,0,.9))-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/(name+".png"))
    bpy.ops.render.render(write_still=True)
manifest={"status":"VISUAL_CANDIDATE", "source":str(blend.relative_to(ROOT)),
          "source_sha256":hashlib.sha256(blend.read_bytes()).hexdigest(),
          "preview_sha256":hashlib.sha256((OUT/"arjun_brother_preview.glb").read_bytes()).hexdigest(),
          "body_origin":"Independent MPFB human", "bone_count":len(rig.data.bones),
          "age_years":29,"role":"Dev, Arjun's older brother and sepoy"}
(OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
print("BROTHER_BUILD",json.dumps(manifest))
