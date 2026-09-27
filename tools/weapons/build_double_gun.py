"""Build an original plain side-by-side percussion sporting gun study.

The 1854 Perrin gun establishes period technology, not this object's exact
decoration or a documented Suryagarh owner.
"""
import bpy
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "environment/weapons/double_percussion_gun"
OUT.mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

def mat(name, rgb, metal=0):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*rgb, 1)
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = .52 if metal else .78
    return material

wood = mat("oiled walnut", (.21,.105,.046))
wood_edge = mat("worn walnut", (.32,.19,.09))
iron = mat("blued steel", (.115,.14,.15), .8)
brass = mat("aged brass", (.37,.25,.10), .65)

def cube(name, location, scale, material, bevel=.008):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel:
        mod = obj.modifiers.new("softened edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        obj.modifiers.new("weighted normals", "WEIGHTED_NORMAL")
    return obj

def tube(name, x0, x1, y, z, radius, material):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=radius, depth=x1-x0,
                                        location=((x0+x1)/2,y,z), rotation=(0,math.pi/2,0))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    return obj

def shaped_stock(name, profiles, material):
    # Elliptical cross sections give the shoulder stock a tapered cheek and
    # narrow wrist instead of a constant rectangular beam.
    sides = 12
    vertices = []
    for x, half_width, half_height, centre_z in profiles:
        for index in range(sides):
            angle = math.tau * index / sides
            vertices.append((x, half_width * math.cos(angle),
                             centre_z + half_height * math.sin(angle)))
    faces = []
    for ring in range(len(profiles) - 1):
        for index in range(sides):
            next_index = (index + 1) % sides
            faces.append((ring*sides+index, ring*sides+next_index,
                          (ring+1)*sides+next_index, (ring+1)*sides+index))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple((len(profiles)-1)*sides+index for index in range(sides)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(material)
    bevel = obj.modifiers.new("soft stock edges", "BEVEL")
    bevel.width = .004
    bevel.segments = 2
    obj.modifiers.new("weighted normals", "WEIGHTED_NORMAL")
    return obj

# +X is the firing direction, matching Arjun's existing long-gun sockets.
shaped_stock("walnut buttstock", [(-.55,.037,.052,-.015),(-.43,.041,.053,-.016),
    (-.31,.037,.047,-.017),(-.19,.030,.034,-.019),(-.10,.026,.029,-.024)], wood)
shaped_stock("stock shoulder heel", [(-.558,.038,.053,-.015),(-.545,.038,.053,-.015)], brass)
cube("slender wrist",(-.08,0,-.025),(.22,.052,.058),wood,.010)
cube("long fore-end",(.27,0,-.044),(.66,.064,.046),wood,.011)
cube("breech block",(.075,0,.008),(.145,.080,.055),iron,.008)
for side in (-1,1):
    y = side*.022
    tube("barrel left" if side < 0 else "barrel right",.10,.99,y,.035,.017,iron)
    tube("muzzle lip",.975,1.00,y,.035,.019,brass)
    tube("percussion nipple",.045,.080,y,.07,.008,iron)
    cube("external hammer",(.03,y,.105),(.05,.020,.085),iron,.004)
    cube("hammer spur",(-.002,y,.146),(.045,.026,.015),iron,.003)
    cube("lock plate",(-.005,side*.040,.005),(.14,.007,.038),iron,.004)
    cube("trigger",(-.11,y,-.07),(.014,.009,.051),iron,.003)
for x in (.42,.77):
    cube("barrel band", (x,0,.028),(.025,.084,.047),brass,.004)
tube("wooden ramrod",.16,.88,0,-.085,.006,wood_edge)
cube("double trigger guard",(-.11,0,-.104),(.17,.025,.014),brass,.004)

source = OUT / "double_percussion_gun.blend"
export = OUT / "double_percussion_gun.glb"
bpy.ops.wm.save_as_mainfile(filepath=str(source))
bpy.ops.export_scene.gltf(filepath=str(export), export_format="GLB",
                          export_apply=True, export_animations=False)
manifest = {
    "source": str(source.relative_to(ROOT)),
    "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
    "export": str(export.relative_to(ROOT)),
    "export_sha256": hashlib.sha256(export.read_bytes()).hexdigest(),
    "basis": "Plain original candidate informed by a dated 1854 double-barreled percussion sporting gun; local ownership is a fiction.",
    "source_url": "https://www.metmuseum.org/art/collection/search/24946",
}
(OUT / "provenance.json").write_text(json.dumps(manifest,indent=2)+"\n")
print("DOUBLE PERCUSSION GUN BUILT", manifest["export_sha256"])
