"""Create an original 1850s Indian percussion sidearm art candidate.

Museum Victoria ST 5901 documents a percussion belt pistol collected during
1857-59. This is a plain game interpretation, not a replica or a claim that a
modern cartridge-based katta existed in this form. +X points toward the muzzle.
"""
import bpy
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "environment/weapons/indian_percussion_pistol"
OUT.mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def material(name, colour, metallic=0.0):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*colour, 1.0)
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*colour, 1.0)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = .56 if metallic else .8
    return result


wood = material("worn dark hardwood", (.19, .095, .042))
iron = material("aged iron", (.105, .115, .115), .75)
brass = material("aged brass", (.36, .235, .075), .6)


def block(name, at, dimensions, surface, bevel=.003, angle=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler[1] = angle
    obj.data.materials.append(surface)
    if bevel:
        mod = obj.modifiers.new("worn edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        obj.modifiers.new("weighted normals", "WEIGHTED_NORMAL")
    return obj


def rod(name, start, end, radius, surface, segments=20):
    from mathutils import Vector
    a, b = Vector(start), Vector(end)
    direction = b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments, radius=radius, depth=direction.length, location=(a+b)*.5)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    obj.data.materials.append(surface)
    return obj


def curved_grip(name, rings, surface):
    sides = 16
    vertices = []
    for x, z, half_x, half_y in rings:
        for index in range(sides):
            angle = math.tau * index / sides
            vertices.append((x + half_x*math.cos(angle), half_y*math.sin(angle), z))
    faces = []
    for ring in range(len(rings)-1):
        for index in range(sides):
            nxt = (index+1) % sides
            faces.append((ring*sides+index,ring*sides+nxt,(ring+1)*sides+nxt,(ring+1)*sides+index))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple((len(rings)-1)*sides+index for index in range(sides)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(surface)
    bevel = obj.modifiers.new("softened stock", "BEVEL")
    bevel.width = .0025
    bevel.segments = 2
    obj.modifiers.new("weighted normals", "WEIGHTED_NORMAL")
    return obj


def muzzle_ring():
    sides = 32
    vertices = []
    for x, radius in [(.173,.0145),(.181,.0145),(.181,.008),(.173,.008)]:
        for i in range(sides):
            angle = math.tau*i/sides
            vertices.append((x, radius*math.cos(angle), .026+radius*math.sin(angle)))
    faces = []
    for ring in range(4):
        nxt = (ring+1)%4
        for i in range(sides):
            j = (i+1)%sides
            faces.append((ring*sides+i,ring*sides+j,nxt*sides+j,nxt*sides+i))
    mesh = bpy.data.meshes.new("hollow muzzle mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("hollow muzzle",mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(iron)
    return obj


# Original stylised production candidate with a continuous rounded stock,
# slender breech and readable muzzle opening. +X is the muzzle direction.
rod("iron barrel", (-.025,0,.026),(.173,0,.026),.0145,iron,32)
muzzle_ring()
# An inset dark bore prevents the rear face of the barrel showing at the tip.
rod("recessed bore", (.1729,0,.026),(.1731,0,.026),.008,material("dark bore",(.018,.018,.017)),32)
block("forestock",(.070,0,.001),(.218,.031,.029),wood,.007)
curved_grip("one piece curved grip", [(-.071,.018,.024,.017),(-.081,-.015,.025,.019),(-.095,-.045,.027,.020),(-.110,-.075,.031,.022),(-.124,-.102,.034,.023),(-.123,-.115,.034,.023)],wood)
block("rounded grip butt plate",(-.123,0,-.117),(.064,.043,.008),brass,.003,.15)
for side in (-1,1):
    block("narrow side lock",(-.026,side*.018,.012),(.062,.006,.025),iron,.003)
    rod("lock screw",(-.044,side*.021,.011),(-.044,side*.024,.011),.0028,brass,12)
# Short swept hammer, resting beside the breech instead of a straight lever.
rod("hammer neck",(-.036,.020,.025),(-.044,.020,.049),.005,iron,12)
rod("hammer head",(-.044,.020,.049),(-.020,.020,.044),.006,iron,12)
rod("hammer spur",(-.047,.020,.048),(-.056,.020,.055),.0035,iron,12)
rod("under-barrel ramrod",(.003,0,-.021),(.169,0,-.021),.0035,iron,12)
rod("ramrod end",(.166,0,-.021),(.175,0,-.021),.0047,brass,12)
rod("trigger",(-.046,0,-.028),(-.054,0,-.053),.003,iron,12)
bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=8,
    location=(-.057,0,-.051), rotation=(math.pi/2,0,0),
    major_radius=.030, minor_radius=.0028)
guard = bpy.context.object
guard.name = "trigger guard"
guard.scale.x = 1.25
guard.data.materials.append(brass)

source = OUT / "indian_percussion_pistol.blend"
export = OUT / "indian_percussion_pistol.glb"
bpy.ops.wm.save_as_mainfile(filepath=str(source))
bpy.ops.export_scene.gltf(filepath=str(export), export_format="GLB", export_apply=True, export_animations=False)
manifest = {
    "source": str(source.relative_to(ROOT)),
    "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
    "export": str(export.relative_to(ROOT)),
    "export_sha256": hashlib.sha256(export.read_bytes()).hexdigest(),
    "basis": "Original single-shot game candidate informed by an early-19th-century percussion pistol collected in India during 1857-59; not a replica or documented modern katta.",
    "source_url": "https://collections.museumsvictoria.com.au/items/400990",
    "status": "candidate; unintegrated and not visually approved"
}
(OUT / "provenance.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("INDIAN PERCUSSION PISTOL CANDIDATE", manifest["export_sha256"])
