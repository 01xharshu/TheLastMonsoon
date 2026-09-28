"""Create static 1857 thana staff candidates from the editable village adult base.

Run with Blender --background --python tools/characters/build_thana_staff.py.
The source body/skin is MPFB CC0; role clothing and objects are original geometry.
"""
import bpy
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "characters/npcs/village_farmer.glb"
DEST = ROOT / "characters/npcs/thana"
DEST.mkdir(parents=True, exist_ok=True)

ROLES = {
    "daroga": {"cotton": (.46, .39, .28, 1), "head": (.48, .37, .25, 1), "wrap": (.34, .19, .12, 1)},
    "mohurrir": {"cotton": (.68, .62, .48, 1), "head": (.61, .55, .43, 1), "wrap": (.21, .28, .36, 1)},
    "burkundaz": {"cotton": (.44, .43, .34, 1), "head": (.32, .36, .30, 1), "wrap": (.29, .24, .18, 1)},
}

def material(name, color):
    result = bpy.data.materials.new(name)
    result.diffuse_color = color
    result.use_nodes = True
    result.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = color
    result.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .91
    return result

def cube(name, location, scale, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("Soft worn edges", 'BEVEL')
    bevel.width = .012
    bevel.segments = 2
    obj.modifiers.new("Weighted normals", 'WEIGHTED_NORMAL')
    return obj

def waist_band(name, color):
    verts = []
    for z in (.885, .947):
        for step in range(24):
            angle = math.tau * step / 24
            verts.append((.242 * math.cos(angle), .197 * math.sin(angle), z))
    faces = [(i, (i + 1) % 24, 24 + (i + 1) % 24, 24 + i) for i in range(24)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(color)
    return obj

for role, colors in ROLES.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':
            continue
        # Import creates local material copies on each independent build.
        for mat in obj.data.materials:
            if mat is None:
                continue
            name = mat.name.lower()
            color = None
            if "cotton" in name or "upper base" in obj.name.lower():
                color = colors["cotton"]
            if "head cloth" in name or "head wrap" in name:
                color = colors["head"]
            if color is not None:
                mat.diffuse_color = color
                if mat.use_nodes and mat.node_tree.nodes.get("Principled BSDF"):
                    base = mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"]
                    for link in list(base.links):
                        mat.node_tree.links.remove(link)
                    base.default_value = color
    wrap = material("Role cotton sash", colors["wrap"])
    wood = material("Oiled lathi wood", (.22, .13, .07, 1))
    if role == "daroga":
        waist_band("Daroga waist sash", wrap)
        cube("Daroga shoulder cloth", (.14, -.218, 1.17), (.065, .014, .40), wrap).rotation_euler[1] = -.43
    elif role == "mohurrir":
        waist_band("Mohurrir waist cloth", wrap)
        folio = material("Bound record folio", (.27, .17, .09, 1))
        cube("Record folio", (.42, -.13, .80), (.27, .06, .36), folio).rotation_euler[1] = -.18
    else:
        waist_band("Burkundaz waist sash", wrap)
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=.024, depth=1.42,
                                             location=(.47, -.13, .73))
        staff = bpy.context.object
        staff.name = "Wooden watch staff"
        staff.rotation_euler[1] = .12
        staff.data.materials.append(wood)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(DEST / (role + ".glb")),
                              export_format='GLB', use_selection=True,
                              export_animations=False, export_cameras=False,
                              export_lights=False)
    # A studio image makes the candidate's actual clothing inspectable.
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 540
    scene.render.resolution_y = 700
    scene.render.resolution_percentage = 100
    world = bpy.data.worlds.new("Neutral review world")
    world.color = (.25, .26, .27)
    scene.world = world
    light_data = bpy.data.lights.new("Review area", 'AREA')
    light_data.energy = 650
    light_data.shape = 'DISK'
    light_data.size = 4
    light = bpy.data.objects.new("Review area", light_data)
    scene.collection.objects.link(light)
    light.location = (1.8, -2.6, 3.0)
    from mathutils import Vector
    light.rotation_euler = (Vector((0, 0, .9)) - light.location).to_track_quat('-Z', 'Y').to_euler()
    camera_data = bpy.data.cameras.new("Review camera")
    camera_data.type = 'ORTHO'
    camera_data.ortho_scale = 2.1
    camera = bpy.data.objects.new("Review camera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = (0, -3, 1.05)
    camera.rotation_euler = (Vector((0, 0, .9)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.camera = camera
    scene.render.filepath = str(DEST / (role + "_review.png"))
    bpy.ops.render.render(write_still=True)
    print("THANA_STAFF", role, (DEST / (role + ".glb")).stat().st_size)

(DEST / "manifest.json").write_text(json.dumps({
    "status": "visual_candidate_unapproved",
    "source": "characters/npcs/village_farmer.glb",
    "base_license": "MPFB core CC0-1.0",
    "roles": list(ROLES),
    "scope": "stationary staff inside DistrictPolice only"
}, indent=2) + "\n")
