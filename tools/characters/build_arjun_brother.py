"""Create an independent MakeHuman/MPFB sepoy candidate for Dev, Arjun's brother."""
import bpy
import hashlib
import json
import math
from pathlib import Path
from mathutils import Vector, Quaternion

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
upper_group.add([v.index for v in outfit.data.vertices if find(v.index)==upper_component], 1, 'REPLACE')
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
rings("Coat lower skirts", [(.76,.275,.23,0,0),(.84,.255,.205,0,0),(.96,.212,.166,0,0),(1.055,.155,.125,0,0)], coat)
rings("Coat waist seam", [(.96,.232,.187,0,0),(.975,.232,.187,0,0)], trim)
for side,sign in [("left",1),("right",-1)]:
    suffix = "l" if sign == 1 else "r"
    thigh = rig.data.bones["thigh_" + suffix]
    calf = rig.data.bones["calf_" + suffix]
    levels = []
    for z in [.20,.30,.42,.47,.52,.57,.68,.84]:
        bone = calf if z < calf.head_local.z else thigh
        t = (z-bone.head_local.z)/(bone.tail_local.z-bone.head_local.z)
        center = bone.head_local.lerp(bone.tail_local,t)
        radius = .092 + .026 * (z-.20)/.64
        levels.append((z,radius,radius,center.x,center.y))
    trousers = rings(side+" trouser",levels,cotton,"thigh_"+suffix)
    trousers.vertex_groups.clear()
    for vertex in trousers.data.vertices:
        upper = max(0,min(1,(vertex.co.z-.43)/.13))
        for name,weight in [("thigh_"+suffix,upper),("calf_"+suffix,1-upper)]:
            if weight > 0:
                (trousers.vertex_groups.get(name) or trousers.vertex_groups.new(name=name)).add([vertex.index],weight,'REPLACE')
    tube(side+" boot",(sign*.17,-.016,.32),(sign*.188,-.011,.075),.11,.094,leather,"calf_"+suffix)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, location=(sign*.19,-.067,.041))
    shoe=bpy.context.object; shoe.name=side+" leather shoe"
    shoe.scale=(.112,.18,.059); shoe.data.materials.append(leather)
    shoe.parent=rig
    group=shoe.vertex_groups.new(name="foot_"+("l" if sign==1 else "r"))
    group.add(list(range(len(shoe.data.vertices))),1,'REPLACE')
    shoe.modifiers.new("Rig",'ARMATURE').object=rig
# Broad webbing crosses the front of the coat without a cylindrical silhouette.
attach("Crossbody leather webbing",[(-.205,-.12,1.345),(-.165,-.125,1.345),(.16,-.186,.91),(.12,-.193,.91)],
       [(0,1,2,3)],leather,"spine01")
attach("Coat front placket",[(-.018,-.205,.87),(.018,-.205,.87),
                               (-.018,-.175,1.0),(.018,-.175,1.0),
                               (-.018,-.155,1.35),(.018,-.155,1.35),
                               (-.018,-.105,1.405),(.018,-.105,1.405)],
       [(0,1,3,2),(2,3,5,4),(4,5,7,6)],coat,"spine01")
for i in range(6):
    z=1.01+i*.065
    y=-.174+.015*(z-1.0)/.33
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
