"""Run with Blender --background --python tools/world/prepare_nature.py.
Derive bounded game meshes from the recorded, unmodified CC0 glTF sources.
"""
import bpy, bmesh, pathlib, json, hashlib, sys
from mathutils import Vector
ROOT = pathlib.Path(__file__).resolve().parents[2]
only = sys.argv[sys.argv.index('--only')+1] if '--only' in sys.argv else None
reports=json.loads((ROOT/'docs/world/derived_assets.json').read_text()) if only else []
for slug, target, select in [('island_tree_02',18000,None),('boulder_01',1800,None),('grass_bermuda_01',0,'grass_bermuda_01_medium_b')]:
    if only and slug != only: continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    source=ROOT/'WorkingAssets/Suryagarh/source'/slug/(slug+'_1k.gltf')
    bpy.ops.import_scene.gltf(filepath=str(source))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    if select:
        for o in objects:
            if o.name != select:bpy.data.objects.remove(o,do_unlink=True)
        objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for o in objects:
        bpy.context.view_layer.objects.active=o;o.select_set(True)
        bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
        if slug == 'boulder_01':
            bm=bmesh.new();bm.from_mesh(o.data)
            bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.0001)
            bm.to_mesh(o.data);bm.free()
        before=sum(len(p.vertices)-2 for p in o.data.polygons)
        if target and before>target:
            mod=o.modifiers.new('Game triangle budget','DECIMATE');mod.ratio=target/before
            bpy.ops.object.modifier_apply(modifier=mod.name)
        # Anchor at ground and center horizontally. glTF imports into Blender Z-up.
        bounds=[Vector(c) for c in o.bound_box]
        center=Vector(((min(v.x for v in bounds)+max(v.x for v in bounds))/2,(min(v.y for v in bounds)+max(v.y for v in bounds))/2,min(v.z for v in bounds)))
        for v in o.data.vertices:v.co-=center
        o.location=(0,0,0)
        if slug == 'grass_bermuda_01':
            for v in o.data.vertices: v.co *= 4.0
        for mat in o.data.materials:
            mat.use_nodes=True
            bsdf=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
            if bsdf:
                # Leaves are modelled geometry; use opaque surfaces to avoid a forest-wide transparent pass.
                for link in list(bsdf.inputs['Alpha'].links):mat.node_tree.links.remove(link)
                bsdf.inputs['Alpha'].default_value=1.0
                mat.diffuse_color[3]=1
                bsdf.inputs['Roughness'].default_value=.85
        o.select_set(False)
    out=ROOT/'assets/nature/models'/(slug+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',export_image_format='AUTO',export_materials='EXPORT')
    tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects)
    reports=[r for r in reports if r['asset'] != slug]
    reports.append(dict(asset=slug,source=str(source.relative_to(ROOT)),output=str(out.relative_to(ROOT)),triangles=tris,sha256=hashlib.sha256(out.read_bytes()).hexdigest(),modifications='Decimated geometry, grounded origin, opaque geometric foliage; 1K source materials retained.'))
    print('PREPARED',slug,tris,flush=True)
(ROOT/'docs/world/derived_assets.json').write_text(json.dumps(reports,indent=2)+'\n')
