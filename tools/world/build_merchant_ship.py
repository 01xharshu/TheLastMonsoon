"""Original fictional 1850s India-trade merchant ship, metres, bow towards -Z.

Run with Blender --background --python tools/world/build_merchant_ship.py.
Produces recoverable .blend and runtime .glb; no downloaded ship geometry.
"""
from pathlib import Path
import math
import json
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/vehicles/ships/hooghly_merchant"
SOURCE = ROOT / "WorkingAssets/Ships"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
groups = {}
materials = {}


def material(name, color, roughness=.75, metallic=0, texture=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if texture:
        image = bpy.data.images.load(str(ROOT / texture))
        image.pack()
        node = mat.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = image
        mat.node_tree.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
    materials[name] = mat
    groups[name] = [[], [], []]


material("TarredHull", (.075, .066, .052), .82)
material("CopperSheathing", (.28, .19, .105), .78, .32)
material("WeatherDeck", (.38, .275, .15), .84)
material("DeckCaulking", (.06, .045, .027), .96)
material("OakSpars", (.29, .20, .10), .80)
material("IvoryRail", (.63, .57, .40), .85)
material("SternOchre", (.41, .29, .11), .78)
material("Ironwork", (.055, .063, .057), .67, .55)
material("StandingRigging", (.065, .055, .038), .94)
material("RunningRigging", (.35, .30, .19), .96)
material("FurledCanvas", (.56, .51, .36), .98)
material("CabinGlass", (.09, .16, .15), .32, .15)
material("CargoWood", (.28, .20, .115), .88)
material("CompanyEnsign", (1, 1, 1), .93, texture="assets/props/flags/eic/prop_eic_checkpoint_flag_01_TLM_EIC_Flag_1801.png")


def face(mat, points, uvs=None):
    verts, faces, texcoords = groups[mat]
    offset = len(verts)
    verts.extend(tuple(p) for p in points)
    faces.append(tuple(range(offset, offset + len(points))))
    texcoords.append(uvs or [(float(i % 2), float(i // 2)) for i in range(len(points))])


def box(mat, center, size):
    c = Vector(center)
    s = Vector(size) / 2
    v = [c + Vector((x * s.x, y * s.y, z * s.z)) for x, y, z in
         [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    for ids in [(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(3,7,6,2),(0,1,5,4)]:
        face(mat, [v[i] for i in ids])


def tube(mat, a, b, radius, end_radius=None, sides=8):
    a, b = Vector(a), Vector(b)
    axis = (b-a).normalized()
    ref = Vector((0,1,0)) if abs(axis.y) < .95 else Vector((1,0,0))
    u = axis.cross(ref).normalized()
    v = axis.cross(u).normalized()
    end_radius = radius if end_radius is None else end_radius
    ra, rb = [], []
    for i in range(sides):
        radial = u * math.cos(i*math.tau/sides) + v * math.sin(i*math.tau/sides)
        ra.append(a + radial*radius)
        rb.append(b + radial*end_radius)
    for i in range(sides):
        j = (i+1) % sides
        face(mat, [ra[i],ra[j],rb[j],rb[i]])
    face(mat, list(reversed(ra)))
    face(mat, rb)


def rope(a, b, thickness=.022, mat="StandingRigging", sag=0):
    a, b = Vector(a), Vector(b)
    previous = a
    for i in range(1, 9 if sag else 2):
        t = i / (8 if sag else 1)
        p = a.lerp(b,t) - Vector((0,sag*math.sin(t*math.pi),0))
        tube(mat, previous, p, thickness, sides=5)
        previous = p


STATIONS = [(-27,.12),(-25,1.0),(-22,2.8),(-18,4.5),(-13,5.5),(-6,5.9),(4,5.9),(13,5.3),(20,4.2),(24,3.4)]


def beam(z):
    for (a,wa),(b,wb) in zip(STATIONS,STATIONS[1:]):
        if a <= z <= b:
            return wa + (wb-wa)*(z-a)/(b-a)
    return STATIONS[0][1] if z < -27 else STATIONS[-1][1]


def sheer(z):
    return .35 * (abs(z)/27)**3


def section_width(z, y):
    profile = [(-4.8,.065),(-4.0,.34),(-2.5,.70),(-.8,.94),(1.0,1.0),(3.3,.96),(4.25,.95)]
    for (a,wa),(b,wb) in zip(profile,profile[1:]):
        if a <= y <= b:
            return beam(z)*(wa+(wb-wa)*(y-a)/(b-a))
    return beam(z)*profile[-1][1]


# Continuous shaped hull, individual plank courses and a proper closed transom.
zs = [-27 + i*51/68 for i in range(69)]
for row in range(37):
    ya = -4.8 + row*8.15/37
    yb = -4.8 + (row+1)*8.15/37
    mat = "CopperSheathing" if yb < -1 else "TarredHull"
    for za,zb in zip(zs,zs[1:]):
        for side in (-1,1):
            pts = [(side*section_width(za,ya),ya+sheer(za),za),
                   (side*section_width(zb,ya),ya+sheer(zb),zb),
                   (side*section_width(zb,yb),yb+sheer(zb),zb),
                   (side*section_width(za,yb),yb+sheer(za),za)]
            face(mat, list(reversed(pts)) if side == 1 else pts)
            # Fine seams do not project as chunky ribs.
            if row > 22:
                rope((side*(section_width(za,yb)+.006),yb+sheer(za),za),
                     (side*(section_width(zb,yb)+.006),yb+sheer(zb),zb), .007, "DeckCaulking")
    z = 24
    face(mat,[(-section_width(z,ya),ya+sheer(z),z),(section_width(z,ya),ya+sheer(z),z),
              (section_width(z,yb),yb+sheer(z),z),(-section_width(z,yb),yb+sheer(z),z)])
box("TarredHull",(0,-4.7,-1.0),(.28,.28,48))

# Deck boards follow the hull outline. Longitudinal seams and staggered butt joints.
for za,zb in zip(zs,zs[1:]):
    wa, wb = beam(za)*.96, beam(zb)*.96
    # Open companionway to the hold. No hidden solid deck across the stairs.
    if za >= 1.5 and zb <= 10.1:
        for side in [-1,1]:
            pts=[(side*1.75,3.32,za),(side*wa,3.32,za),(side*wb,3.32,zb),(side*1.75,3.32,zb)]
            face("WeatherDeck",list(reversed(pts)) if side == 1 else pts)
    else:
        face("WeatherDeck",[(-wb,3.32,zb),(wb,3.32,zb),(wa,3.32,za),(-wa,3.32,za)])
for i in range(-25,26):
    x = i*.22
    valid = [z for z in zs if abs(x) < beam(z)*.955]
    if valid:
        ranges=[(min(valid),1.5),(10.1,max(valid))] if abs(x)<1.75 else [(min(valid),max(valid))]
        for a,b in ranges:
            if b>a: rope((x,3.328,a),(x,3.328,b),.0045,"DeckCaulking")
        for z in range(-21+(i%3),24,5):
            if abs(x)<beam(z)*.94 and not (abs(x)<1.75 and 1.5<z<10.1):
                box("DeckCaulking",(x+.11,3.331,z),(.20,.006,.008))

# Bulwarks, wale bands and caps; port gangway opening at z=4.
for za,zb in zip(zs,zs[1:]):
    for side in (-1,1):
        if side == -1 and za > 2.4 and zb < 5.9:
            continue
        for y,rad,mat in [(1.25,.105,"IvoryRail"),(2.3,.11,"TarredHull"),(3.45,.14,"OakSpars"),(4.3,.095,"IvoryRail")]:
            rope((side*beam(za)*.96,y+sheer(za),za),(side*beam(zb)*.96,y+sheer(zb),zb),rad,mat)
        face("TarredHull",[(side*beam(za)*.955,3.4+sheer(za),za),(side*beam(zb)*.955,3.4+sheer(zb),zb),
                            (side*beam(zb)*.95,4.22+sheer(zb),zb),(side*beam(za)*.95,4.22+sheer(za),za)])
for z in range(-24,24,2):
    for side in (-1,1):
        if side == -1 and 2 < z < 6: continue
        box("OakSpars",(side*(beam(z)*.94-.06),3.88+sheer(z),z),(.11,.95,.13))

# Forecastle and poop with solid cabins, stern gallery, framed windows and access steps.
box("TarredHull",(0,3.79,-20.1),(7.0,.9,7.0))
box("WeatherDeck",(0,4.29,-20.1),(7.1,.10,7.05))
# Cabin walls surround usable space; the front has a two metre doorway.
box("IvoryRail",(0,4.65,23.65),(7.5,2.6,.16))
for side in [-1,1]:
    box("IvoryRail",(side*3.75,4.65,19.35),(.16,2.6,8.7))
    box("IvoryRail",(side*2.4,4.65,15.0),(2.7,2.6,.16))
box("IvoryRail",(0,5.84,15.0),(2.0,.22,.18))
box("WeatherDeck",(0,6.02,19.35),(7.65,.14,8.8))
for x in [-2.9,-1.45,0,1.45,2.9]:
    box("CabinGlass",(x,4.84,23.73),(1.04,1.12,.045))
    for dx in [-.56,.56]: box("SternOchre",(x+dx,4.84,23.79),(.075,1.25,.07))
    for y in [4.21,4.84,5.47]: box("SternOchre",(x,y,23.79),(1.20,.065,.07))
    box("SternOchre",(x,4.84,23.81),(.06,1.12,.05))
for side in [-1,1]:
    for z in [16.2,18.2,20.2,22.2]:
        box("CabinGlass",(side*3.76,4.82,z),(.035,1.0,1.04))
        for dz in [-.57,.57]: box("SternOchre",(side*3.80,4.82,z+dz),(.065,1.14,.07))
    # Poop balustrade; no floating platform outside the hull.
    for z in range(16,24):
        box("IvoryRail",(side*3.7,6.45,z),(.08,.8,.08))
    rope((side*3.7,6.85,15.3),(side*3.7,6.85,23.7),.055,"OakSpars")
box("OakSpars",(0,6.55,23.7),(7.6,.9,.10))
box("OakSpars",(1.12,4.42,15.7),(.10,2.15,1.4))  # door fixed open against the jamb
# Captain's cabin: chart table, shelves, sea chest and a berth along the side.
box("WeatherDeck",(0,4.15,20.2),(2.0,.12,1.3))
for x in [-.8,.8]:
    for z in [19.72,20.68]: box("OakSpars",(x,3.72,z),(.10,.78,.10))
box("FurledCanvas",(0,4.221,20.2),(1.35,.009,.72))
for z in [16.8,17.5,18.2]: box("OakSpars",(3.15,4.15,z),(.5,.07,.64))
box("OakSpars",(-2.7,3.70,20.9),(1.55,.65,2.5))
box("FurledCanvas",(-2.7,4.1,20.9),(1.4,.20,2.4))
box("FurledCanvas",(-2.7,4.23,21.8),(1.1,.12,.48))
box("CargoWood",(2.6,3.69,22.7),(1.55,.72,.8))
for side in [-1,1]:
    for i in range(12):
        box("WeatherDeck",(side*2.7,3.38+i*.225,12.1+i*.24),(1.2,.12,.29))
    rope((side*3.3,4.2,12),(side*3.3,6.9,15),.05,"OakSpars")
for i in range(5): box("WeatherDeck",(2.0,3.38+i*.18,-15.5-i*.3),(1.25,.14,.34))

# Hatches with coamings, gratings, deck bitts and a working-looking capstan.
for z in [-6.5]:
    box("OakSpars",(0,3.52,z),(3.35,.4,4.2))
    box("DeckCaulking",(0,3.735,z),(3.0,.025,3.9))
    for x in range(-7,8): box("WeatherDeck",(x*.19,3.78,z),(.08,.07,3.9))
    for j in range(-10,11): box("WeatherDeck",(0,3.785,z+j*.18),(3.0,.065,.055))
# Companionway coamings, handrails and a twenty-step descent to the dry hold.
for side in [-1,1]:
    box("OakSpars",(side*1.8,3.5,5.8),(.12,.34,8.5))
    rope((side*1.4,4.1,1.5),(side*1.4,-.1,9.5),.045,"OakSpars")
for i in range(20):
    box("WeatherDeck",(0,3.26-i*.216,1.8+i*.4),(2.4,.12,.43))
box("WeatherDeck",(0,-1.10,0),(7.1,.16,36))
for x in range(-15,16): rope((x*.22,-1.014,-18),(x*.22,-1.014,18),.005,"DeckCaulking")
for z in range(-16,18,4):
    if 1.5 < z < 10.1:
        for side in [-1,1]: box("OakSpars",(side*3.0,2.97,z),(2.4,.25,.24))
    else:
        box("OakSpars",(0,2.97,z),(8.4,.25,.24))
    for side in [-1,1]: box("OakSpars",(side*3.0,.95,z),(.20,3.8,.20))
# Hold cargo sits off the central walk route.
for side in [-1,1]:
    for z in [-7,-5,-3,-1,11,13,15]:
        x=side*2.95
        box("CargoWood",(x,-.44,z),(.8,1.12,1.45))
        for y in [-.91,.02]: box("OakSpars",(x,y,z),(.88,.10,1.53))
        rope((x-.4,.16,z-.7),(x+.4,-1,z+.7),.026,"RunningRigging")
    for z in [-15,-12]:
        box("OakSpars",(side*2.35,-.4,z),(1.5,.16,2.5))
        box("FurledCanvas",(side*2.35,-.20,z),(1.35,.22,2.35))
        box("FurledCanvas",(side*2.35,-.04,z+.75),(1.1,.12,.42))
for z in [-19,-10,10,20]:
    for side in [-1,1]:
        x = side*(beam(z)*.78)
        for dz in [-.28,.28]: tube("OakSpars",(x,3.32,z+dz),(x,4.1,z+dz),.13)
        box("OakSpars",(x,3.96,z),(.26,.20,1.05))
for z in [-11,11]:
    tube("Ironwork",(0,3.32,z),(0,4.18,z),.33,.26,12)
    tube("OakSpars",(0,4.18,z),(0,4.38,z),.48,.48,12)
    for i in range(8):
        a = i*math.tau/8
        rope((.25*math.cos(a),4.31,z+.25*math.sin(a)),(1.55*math.cos(a),4.31,z+1.55*math.sin(a)),.045,"OakSpars")

# Steering wheel: brass/iron hub, timber spokes and rim on the poop.
box("OakSpars",(0,6.43,19),(.22,.82,.28))
for i in range(16):
    a, b = i*math.tau/16, (i+1)*math.tau/16
    rope((.61*math.cos(a),7.1+.61*math.sin(a),19),(.61*math.cos(b),7.1+.61*math.sin(b),19),.035,"OakSpars")
for i in range(8):
    a=i*math.tau/8
    rope((0,7.1,19),(.73*math.cos(a),7.1+.73*math.sin(a),19),.035,"OakSpars")
tube("Ironwork",(0,7.1,18.92),(0,7.1,19.12),.09)

# Tapered three-part masts, top platforms, yards, furled sails, shrouds and ratlines.
mast_data = [(-14.6,21.5,34.5,19.0),(.0,24.5,39.0,21.0),(13.2,19.5,31.0,15.0)]
for index,(z,lower,total,yard_width) in enumerate(mast_data):
    tube("OakSpars",(0,3.32,z),(0,lower,z),.38 if index==1 else .32,.24,12)
    tube("OakSpars",(0,lower-1.3,z),(0,total-4.3,z),.21,.105,10)
    tube("OakSpars",(0,total-5,z),(0,total,z),.105,.035,8)
    box("OakSpars",(0,lower-.8,z),(3.1,.15,2.4))
    for dy in [lower-3,lower-1.5]: tube("Ironwork",(0,dy,z),(0,dy+.12,z),.25,.25,12)
    for level,y in enumerate([lower-4,lower+3.4,total-3.4]):
        width = yard_width * [1,.67,.42][level]
        tube("OakSpars",(-width/2,y,z-.16),(width/2,y,z-.16),.16 if level==0 else .105,.085,10)
        # Rolled canvas rests on the yard, held by rope gaskets.
        segments = 16
        for j in range(segments):
            xa=-width/2+j*width/segments
            xb=-width/2+(j+1)*width/segments
            bulge=.17 + .05*math.sin(j*1.7+index)
            tube("FurledCanvas",(xa,y+.18,z-.12),(xb,y+.18,z-.12),bulge,bulge*.92,8)
        for j in range(1,int(width)):
            x=-width/2+j
            rope((x,y-.12,z-.36),(x,y+.38,z+.04),.018,"RunningRigging")
        rope((-width*.46,y-.48,z-.25),(width*.46,y-.48,z-.25),.02,"RunningRigging",.45)
        for side in [-1,1]:
            rope((side*width*.48,y,z-.16),(0,min(total-.7,y+4),z),.025)
            rope((side*width*.48,y,z-.16),(side*4.5,3.7,z+4),.022,"RunningRigging",.3)
    for side in [-1,1]:
        for strand in range(5):
            base_z=z-2+strand
            rope((side*5.0,3.6,base_z),(side*.16,lower-.5,z),.036)
            tube("OakSpars",(side*5.0,3.5,base_z),(side*5.0,3.85,base_z),.13,.13,8)
        for rung in range(1,34):
            y=3.8+rung*.44
            t=(y-3.6)/(lower-.5-3.6)
            if t>.95: break
            x=side*(5.0+( .16-5.0)*t)
            rope((x,y,z-2*(1-t)),(x,y,z+2*(1-t)),.013)
        rope((side*4.5,4,z+3.3),(0,total-4.3,z),.027)
    target = (0,5.3,-29) if index == 0 else (0,mast_data[index-1][1]-3,mast_data[index-1][0])
    rope((0,lower,z),target,.046)
    rope((0,total-4.5,z),(0,7.4,-35) if index==0 else (0,mast_data[index-1][2]-5,mast_data[index-1][0]),.028)

# Fixed bowsprit, dolphin striker, head rails, anchor gear and side anchors.
tube("OakSpars",(0,4.1,-23),(0,8.0,-38),.29,.10,12)
tube("OakSpars",(0,6.2,-32),(0,8.8,-41),.12,.055,8)
tube("Ironwork",(0,6.3,-32),(0,2.8,-32),.055,.04,8)
rope((0,2.8,-32),(0,8.0,-38),.038)
rope((0,2.8,-32),(0,-.2,-26.7),.045)
rope((0,8.0,-38),(0,28,-14.6),.027)
for side in [-1,1]:
    rope((side*3.0,4.4,-22),(0,7.0,-35),.04)
    tube("OakSpars",(side*2.7,4,-22),(side*4.4,4.2,-24),.16,.12)
    rope((side*4.2,4.2,-24),(side*4.2,.8,-24),.055)
    tube("Ironwork",(side*4.2,.4,-24),(side*4.2,2.6,-24),.10)
    tube("Ironwork",(side*4.2-1.0,2.0,-24),(side*4.2+1.0,2.0,-24),.085)
    for dx in [-1,1]:
        rope((side*4.2,.4,-24),(side*4.2+dx*.85,.95,-24),.09,"Ironwork")
        box("Ironwork",(side*4.2+dx*.85,.95,-24),(.35,.24,.40))

# A modest period company ensign: existing project flag texture, visibly attached.
flag_z = 13.2
for x in range(12):
    for y in range(6):
        pts=[]; uv=[]
        for dx,dy in [(0,0),(1,0),(1,1),(0,1)]:
            u,v=(x+dx)/12,(y+dy)/6
            pts.append((u*3.0,29.7-v*1.5,flag_z+math.sin(u*5-v*1.4)*u*.28))
            uv.append((u,1-v))
        face("CompanyEnsign",pts,uv)

# Small lashed cargo boxes by the hatch, kept clear of the port gangway route.
for x,z in [(2.7,-7.5),(3.7,-7.5),(2.7,-6.4),(2.7,8.5)]:
    box("CargoWood",(x,3.85,z),(.85,1.05,.85))
    for y in [3.44,4.26]: box("OakSpars",(x,y,z),(.93,.08,.92))
    rope((x-.4,4.4,z-.4),(x+.4,3.36,z+.4),.025,"RunningRigging")

# Convert the batched geometry to a small number of export meshes.
for name,(verts,faces,uvs) in groups.items():
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.materials.append(materials[name])
    mesh.update()
    uv_layer=mesh.uv_layers.new(name="UVMap")
    for poly,coords in zip(mesh.polygons,uvs):
        for loop_id,coord in zip(poly.loop_indices,coords): uv_layer.data[loop_id].uv=coord
    obj=bpy.data.objects.new("merchant_"+name,mesh)
    bpy.context.collection.objects.link(obj)

# Asset dimensions and named role are recoverable even without the generator.
bpy.context.scene["asset_role"]="Fictional 1850s British India-trade merchantman, moored and furled"
bpy.context.scene["hull_length_m"]=51.0
bpy.context.scene["beam_m"]=11.8
bpy.context.scene["draft_m"]=4.8
bpy.context.scene["waterline_y"]=0.0
# Blender's world Z is up. The builder above uses engine Y up; rotate the whole
# geometry into Blender coordinates before glTF converts it back to engine Y up.
for obj in bpy.context.scene.objects:
    obj.rotation_euler[0]=math.pi/2
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "hooghly_merchant_1850s.blend"))
bpy.ops.export_scene.gltf(filepath=str(OUT / "hooghly_merchant_1850s.glb"),export_format="GLB",export_yup=True)
(OUT / "manifest.json").write_text(json.dumps({"name":"Fictional Hooghly merchantman","era":"1850s","source":"Original project geometry","generator":"tools/world/build_merchant_ship.py","blend":"WorkingAssets/Ships/hooghly_merchant_1850s.blend","hull_length_m":51,"beam_m":11.8,"draft_m":4.8,"mast_count":3,"state":"Moored, furled; explorable main deck, forecastle, helm, captain cabin, cargo hold and crew berths","historical_approval":False},indent=2)+"\n")
print("HOOGHLY MERCHANT SHIP EXPORT PASS")
