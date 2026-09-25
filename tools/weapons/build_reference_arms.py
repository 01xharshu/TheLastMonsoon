"""Create original, isolated bow, quiver, arrow and spear study assets.

The owner's cropped equipment board guides silhouettes only. No image mesh or
texture is extracted. These props are for standalone review, not character fit.
Run: Blender --background --python tools/weapons/build_reference_arms.py
"""
import bpy
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "environment/weapons"
EVIDENCE = ROOT / "docs/characters/arjun/weapon_set_reference_2026-09-23.png"
bpy.context.preferences.filepaths.save_version = 0


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def material(name, color, metallic=0.0, roughness=0.72):
    item = bpy.data.materials.new(name)
    item.diffuse_color = (*color, 1)
    item.use_nodes = True
    shader = item.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    return item


WOOD = material("Dark seasoned hardwood", (0.12, 0.062, 0.026))
LEATHER = material("Aged oiled leather", (0.105, 0.052, 0.026))
LEATHER_EDGE = material("Worn leather edge", (0.19, 0.105, 0.055))
IRON = material("Hand forged dark iron", (0.18, 0.21, 0.22), 0.75, 0.46)
IRON_EDGE = material("Polished worn iron edges", (0.36, 0.39, 0.38), 0.82, 0.31)
HORN = material("Dark horn reinforcement", (0.085, 0.075, 0.058), 0.04, 0.43)
THREAD = material("Natural bow cord", (0.59, 0.50, 0.34))
FEATHER = material("Arrow fletching", (0.32, 0.27, 0.19))
FEATHER_LIGHT = material("Pale arrow fletching", (0.54, 0.47, 0.34))
WOOD_GRAIN = material("Bow and spear grain accent", (0.19, 0.105, 0.044))
STITCH = material("Natural linen stitching", (0.52, 0.44, 0.31))


def tube(name, points, radius, mat):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, position in zip(spline.points, points):
        point.co = (*position, 1)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def cylinder(name, radius, depth, z, mat, vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=(0, 0, z))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def mesh(name, verts, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def save(name):
    path = OUT / name
    path.mkdir(parents=True, exist_ok=True)
    source = path / (name + ".blend")
    output = path / (name + ".glb")
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB", export_apply=True, export_animations=False)
    return {"source": str(source.relative_to(ROOT)), "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "output": str(output.relative_to(ROOT)), "output_sha256": hashlib.sha256(output.read_bytes()).hexdigest()}


def stave():
    # Resting bow, 1.30 m tip to tip. Belly curves toward the string.
    rings, sides = [], 12
    for i in range(25):
        t = i / 24
        z = (t - .5) * 1.30
        x = -.12 * math.sin(math.pi * abs(2*t-1)/2) ** 1.3
        radius = .020 * (1 - .52 * abs(2*t-1))
        rings.append([(x + radius*math.cos(2*math.pi*j/sides), radius*.65*math.sin(2*math.pi*j/sides), z)
                      for j in range(sides)])
    verts = [v for ring in rings for v in ring]
    faces = []
    for i in range(24):
        for j in range(sides):
            a = i*sides+j
            b = i*sides+(j+1)%sides
            faces.append((a,b,b+sides,a+sides))
    mesh("Tapered bent wooden bow stave", verts, faces, WOOD)
    tube("Taut natural cord", [(-.12,0,-.65),(-.12,0,.65)], .0018, THREAD)
    for offset in [-.012,.012]:
        tube("Laminated bow limb grain", [(-.12*math.sin(math.pi*abs(2*i/40-1)/2)**1.3+offset, -.012, (i/40-.5)*1.27)
                                           for i in range(41)], .0014, WOOD_GRAIN)
    for z in [-.65,.65]:
        tip_sign = 1 if z > 0 else -1
        tube("Horn reinforced bow nock", [(-.12,0,z-tip_sign*.028),(-.12,0,z),(-.115,0,z+tip_sign*.018)], .006, HORN)
        tube("Cord groove at nock", [(-.126,-.008,z-tip_sign*.006),(-.12,0,z),(-.126,.008,z+tip_sign*.006)], .0015, LEATHER_EDGE)
    for z in [-.074+i*.012 for i in range(13)]:
        tube("Crossed leather grip wrap", [(-.016,-.010,z),(-.006,-.016,z+.004),(.009,-.014,z+.009)], .0035, LEATHER_EDGE)
    tube("Grip wrap end binding lower", [(-.02,0,-.083),(-.014,-.013,-.083),(.006,-.015,-.083),(.018,0,-.083)], .0022, STITCH)
    tube("Grip wrap end binding upper", [(-.02,0,.084),(-.014,-.013,.084),(.006,-.015,.084),(.018,0,.084)], .0022, STITCH)


def arrow(x=0.0, y=0.0, z=0.0, index=0, inverted=False, scale=1.0):
    height = lambda local: z + (.77-local if inverted else local)*scale
    shaft = cylinder("Arrow %02d hardwood shaft" % index, .0036, .72*scale, height(.36), WOOD, 12)
    shaft.location.x, shaft.location.y = x, y
    tube("Arrow %02d nock binding" % index, [(x+.0043*math.cos(a),y+.0043*math.sin(a),height(.022))
          for a in [2*math.pi*i/16 for i in range(17)]], .0011, STITCH)
    tube("Arrow %02d split nock" % index, [(x-.003,y,height(.004)),(x,y,height(.012)),(x+.003,y,height(.004))], .0011, HORN)
    for side in range(3):
        angle = side*2*math.pi/3
        dx, dy = .014*math.cos(angle), .014*math.sin(angle)
        mesh("Arrow %02d feather %d" % (index,side),
             [(x,y,height(.03)),(x+dx,y+dy,height(.055)),(x+dx,y+dy,height(.18)),(x,y,height(.16))],
             [(0,1,2),(0,2,3)], FEATHER_LIGHT if side == 1 else FEATHER)
        tube("Arrow %02d feather quill %d" % (index,side),
             [(x,y,height(.026)),(x+dx*.70,y+dy*.70,height(.105)),(x,y,height(.165))],
             .0008, FEATHER_LIGHT)
    tip = mesh("Arrow %02d forged point" % index,
               [(x-.012,y,height(.72)),(x+.012,y,height(.72)),(x,y-.003,height(.72)),(x,y+.003,height(.72)),(x,y,height(.77))],
               [(0,2,4),(2,1,4),(1,3,4),(3,0,4)], IRON)
    return tip


def quiver():
    # Open leather cylinder; the arrows remain separate meshes for later draw logic.
    sides = 24
    verts = []
    for radius,z in [(.052,0),(.056,.54),(.049,0),(.049,.54)]:
        verts += [(radius*math.cos(2*math.pi*i/sides), radius*math.sin(2*math.pi*i/sides),z) for i in range(sides)]
    faces = []
    for start_a,start_b in [(0,24),(48,72),(0,48),(24,72)]:
        for i in range(sides):
            j=(i+1)%sides
            faces.append((start_a+i,start_a+j,start_b+j,start_b+i))
    mesh("Leather quiver shell and open rim",verts,faces,LEATHER)
    for z in [.045,.27,.505]:
        tube("Reinforcing leather band",[(.059*math.cos(2*math.pi*i/32),.059*math.sin(2*math.pi*i/32),z) for i in range(33)],.004,LEATHER_EDGE)
    for i in range(32):
        angle = 2*math.pi*i/32
        for z in [.045,.505]:
            tube("Quiver band stitch",[(.06*math.cos(angle),.06*math.sin(angle),z-.006),
                                      (.06*math.cos(angle+.025),.06*math.sin(angle+.025),z+.006)],.00075,STITCH)
    for side in range(2):
        angle = -.32 + side*.64
        tube("Quiver vertical seam",[(.056*math.cos(angle),.056*math.sin(angle),.04+i*.045) for i in range(11)],.002,LEATHER_EDGE)
        for i in range(10):
            z=.05+i*.045
            tube("Cross stitch",[(.055*math.cos(angle-.045),.055*math.sin(angle-.045),z),
                                  (.058*math.cos(angle+.045),.058*math.sin(angle+.045),z+.02)],.0012,STITCH)
    tube("Shoulder carry strap",[(.055,0,.50),(.18,-.07,.45),(.18,-.10,.12),(.055,0,.07)],.011,LEATHER)
    for i in range(7):
        angle = 2*math.pi*i/7
        arrow(.028*math.cos(angle),.028*math.sin(angle),.08-(i%3)*.012,i+1,True,.85)


def spear():
    cylinder("Ash spear shaft",.017,1.55,.775,WOOD,16)
    cylinder("Iron socket",.021,.11,1.54,IRON,16)
    for angle in [0,math.pi]:
        tube("Spear socket rivet",[(.022*math.cos(angle),.022*math.sin(angle),1.515),
                                    (.024*math.cos(angle),.024*math.sin(angle),1.515)],.0035,IRON_EDGE)
    for z in [.25,1.42]:
        cylinder("Binding collar",.018,.022,z,LEATHER_EDGE,16)
    # Leaf shaped, double sided head with a central ridge and narrow point.
    verts=[(0,0,1.56),(-.038,0,1.65),(0,-.010,1.68),(.038,0,1.65),
           (-.036,0,1.76),(0,-.010,1.75),(.036,0,1.76),(0,0,1.91),
           (0,.010,1.68),(0,.010,1.75)]
    faces=[(0,1,2),(0,2,3),(1,4,5,2),(2,5,6,3),(4,7,5),(5,7,6),
           (0,8,1),(0,3,8),(1,8,9,4),(3,6,9,8),(4,9,7),(6,7,9)]
    mesh("Leaf shaped forged spear head",verts,faces,IRON)
    for face_y in [-.011,.011]:
        tube("Spear blade central ridge highlight",[(0,face_y,1.61),(0,face_y,1.75),(0,0,1.90)],.0016,IRON_EDGE)
    cylinder("Iron butt cap",.018,.045,.018,IRON,16)
    for angle in [0,2.09,4.18]:
        tube("Shaft grain",[(.0175*math.cos(angle+.08*math.sin(z*11)),.0175*math.sin(angle+.08*math.sin(z*11)),z)
                             for z in [.08+i*.048 for i in range(29)]],.0011,WOOD_GRAIN)
    for z in [.34+i*.018 for i in range(9)]:
        tube("Spear leather grip",[(.019*math.cos(2*math.pi*i/24),.019*math.sin(2*math.pi*i/24),z+.003*i/24)
                                    for i in range(25)],.0028,LEATHER_EDGE)


report={"reference": str(EVIDENCE.relative_to(ROOT)), "reference_sha256": hashlib.sha256(EVIDENCE.read_bytes()).hexdigest(),
        "status": "STANDALONE_STUDY_NOT_APPROVED", "assets": []}
for name,builder in [("period_bow",stave),("period_arrow",arrow),("period_quiver",quiver),("period_spear",spear)]:
    clear()
    builder()
    report["assets"].append(save(name))
path=ROOT/"docs/characters/arjun/weapon_set_build.json"
path.write_text(json.dumps(report,indent=2)+"\n")
print("WEAPON_SET_BUILT",json.dumps(report),flush=True)
