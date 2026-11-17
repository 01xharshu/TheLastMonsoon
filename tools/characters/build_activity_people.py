"""Derive expressive adult actors from retained Blender MPFB characters.

Run with Blender --background --python this_file. Original donors are read-only.
"""
import bpy, json, math, sys, hashlib
from mathutils import Vector
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/characters'))
from whole_body_contract import retain_complete_body

DONORS = {'artisan': 'workman_01', 'dairyman': 'workman_02',
          'scholar': 'male_02', 'teacher': 'male_03'}

def build(role, donor):
    source = ROOT / f'WorkingAssets/NPCs/indian_street_variants/{donor}/{donor}.blend'
    bpy.ops.wm.read_factory_settings(use_empty=True)
    runtime_donor = ROOT / f'characters/npcs/street_residents/{donor}.glb'
    bpy.ops.import_scene.gltf(filepath=str(runtime_donor))
    bpy.context.preferences.filepaths.save_version = 0
    rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    rig.data.pose_position = 'REST'
    rig.animation_data_clear()
    body = next(o for o in bpy.data.objects if o.type == 'MESH' and 'makehuman_body' in o.name.lower())
    retain_complete_body(body)
    bpy.context.view_layer.update()
    # Bake the donor's evaluated physique and helper exclusion, retaining all
    # human skin. Do not export MPFB macro targets as expression targets.
    dg = bpy.context.evaluated_depsgraph_get()
    mesh = body.data.copy()
    # Import the verified runtime bind pose instead of mixing the source's
    # nonzero authoring arm pose with a newly evaluated rest body.
    actor_body = bpy.data.objects.new(role + '_complete_MakeHuman_body', mesh)
    bpy.context.collection.objects.link(actor_body)
    for group in body.vertex_groups: actor_body.vertex_groups.new(name=group.name)
    actor_body.parent = rig
    actor_body.matrix_parent_inverse = body.matrix_parent_inverse.copy()
    actor_body.matrix_basis = body.matrix_basis.copy()
    actor_body.modifiers.new('Original MPFB armature', 'ARMATURE').object = rig
    actor_body['adult_character'] = True
    actor_body['source_mpfb_body'] = body.name
    # Retain the donor clothes as editable reference, then fit fresh cotton
    # work garments to this exact body/bind pose. The previous donor shirt
    # has pointed cuff/shoulder boundaries in extreme work poses.
    old_clothes = []
    for obj in bpy.data.objects:
        if obj.type == 'MESH' and (obj.name == 'Fitted cotton upper base' or 'Street folded dhoti' in obj.name or 'Street dhoti waist fold' in obj.name or 'Bordered shoulder shawl' in obj.name):
            old_clothes.append(obj)
            obj.hide_render = True
            obj.hide_set(True)
    inv_rig = rig.matrix_world.inverted()
    hip = (rig.matrix_world @ rig.data.bones['pelvis'].head_local).z
    neck = (rig.matrix_world @ rig.data.bones['neck_01'].head_local).z
    world_points = [body.matrix_world @ v.co for v in mesh.vertices]
    skin_weights = [{body.vertex_groups[g.group].name:g.weight for g in v.groups} for v in mesh.vertices]
    def upper(index):
        p=world_points[index];w=skin_weights[index]
        arms=sum(value for name,value in w.items() if name.startswith(('lowerarm_','hand_','index_','middle_','ring_','pinky_','thumb_')))
        return hip-.035 < p.z < neck-.025 and arms < .40
    def lower(index):
        p=world_points[index]
        w=skin_weights[index]
        arms=sum(value for name,value in w.items() if any(part in name.lower() for part in ('arm','hand','index','middle','ring','pinky','thumb')))
        return .105 < p.z < hip+.07 and arms<.05
    mesh.calc_loop_triangles()
    for label, accepted, clearance in [('Activity cotton shirt',upper,.025),('Activity cotton trousers',lower,.035)]:
        faces=[tuple(tri.vertices) for tri in mesh.loop_triangles if all(accepted(i) for i in tri.vertices)]
        ids=sorted({i for face in faces for i in face});mapping={i:j for j,i in enumerate(ids)}
        points=[]
        for i in ids:
            p=world_points[i].copy()
            normal=body.matrix_world.to_3x3() @ mesh.vertices[i].normal
            normal.normalize()
            p+=normal*clearance
            # Cotton trousers bridge the front of the pelvis without copying
            # small anatomical surface detail into the outer garment.
            if label.endswith('trousers') and hip-.20<p.z<hip+.07 and abs(p.x)<.12:p.y=min(p.y,-.15)
            points.append(inv_rig @ p)
        cloth_mesh=bpy.data.meshes.new(label);cloth_mesh.from_pydata(points,[],[tuple(mapping[i] for i in face) for face in faces]);cloth_mesh.update()
        cloth=bpy.data.objects.new(label,cloth_mesh);bpy.context.collection.objects.link(cloth);cloth.parent=rig
        for i,source_index in enumerate(ids):
            for name,weight in skin_weights[source_index].items():
                if name in rig.data.bones:(cloth.vertex_groups.get(name) or cloth.vertex_groups.new(name=name)).add([i],weight,'REPLACE')
        cloth.modifiers.new('Same original MPFB skinning','ARMATURE').object=rig
        mat=bpy.data.materials.new(label+' plain woven cotton');mat.diffuse_color=((.38,.31,.20,1) if role in ('artisan','dairyman') else (.52,.46,.34,1))
        mat.use_nodes=True;shader=mat.node_tree.nodes['Principled BSDF'];shader.inputs['Base Color'].default_value=mat.diffuse_color;shader.inputs['Roughness'].default_value=.98
        cloth_mesh.materials.append(mat)
        for polygon in cloth_mesh.polygons:polygon.use_smooth=True
    # Source contains the untouched parametric body as well as this same-physique
    # export surface. The source-only parametric body must not render twice.
    body.hide_render = True
    body.hide_set(True)
    eyes = next((o for o in bpy.data.objects if o.type == 'MESH' and 'eyes' in o.name.lower()), None)
    head_top = max((body.matrix_world @ v.co).z for v in mesh.vertices)
    eye_z = sum((eyes.matrix_world @ v.co).z for v in eyes.data.vertices)/len(eyes.data.vertices) if eyes else head_top-.15
    inverse = actor_body.matrix_world.inverted()
    actor_body.shape_key_add(name='Basis')
    counts = {}
    for expression in ['speech', 'fear', 'blink']:
        key = actor_body.shape_key_add(name='activity_' + expression)
        changed = 0
        for vertex, shaped in zip(mesh.vertices, key.data):
            p = actor_body.matrix_world @ vertex.co
            if p.y > -.04 or p.z < eye_z-.18: continue
            mouth = math.exp(-((p.z-(eye_z-.105))/.017)**2) * math.exp(-(p.x/.045)**4)
            brow = math.exp(-((p.z-(eye_z+.025))/.018)**2) * math.exp(-(p.x/.070)**4)
            q = p.copy()
            if expression == 'speech':
                q.z -= mouth*.006*max(0, min(1, (eye_z-.095-p.z)/.015))
                q.y -= mouth*.001
            elif expression == 'fear':
                q.z += brow*.004*(1-min(1,abs(p.x)/.075))
                q.z -= mouth*.0015
            else:
                eye = math.exp(-((abs(p.x)-.030)/.018)**4)
                lid = math.exp(-((p.z-eye_z)/.011)**4)*eye
                q.z += (eye_z-p.z)*lid*.88
            shaped.co = inverse @ q
            if (q-p).length > 1e-7: changed += 1
        counts[expression] = changed
        key.value = 0
    assert all(counts.values()), counts
    out = ROOT / 'WorkingAssets/NPCs/activity_people' / role
    out.mkdir(parents=True, exist_ok=True)
    runtime = ROOT / 'characters/npcs/activity_people' / (role+'.glb')
    runtime.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(out/(role+'.blend')))
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    selected = []
    for obj in bpy.data.objects:
        if obj.type != 'MESH' or obj == body or obj in old_clothes: continue
        if 'export_cutout' in obj.name and obj != actor_body: continue
        obj.select_set(True)
        selected.append(obj.name)
    actor_body.select_set(True)
    rig.data.pose_position = 'POSE'
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=str(runtime), export_format='GLB', use_selection=True,
        export_animations=False, export_skins=True, export_all_influences=True,
        export_cameras=False, export_lights=False, export_morph=True)
    report = dict(role=role, adult=True, provenance='Reused Blender MakeHuman/MPFB donor',
        donor=str(source.relative_to(ROOT)), donor_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
        runtime_donor=str(runtime_donor.relative_to(ROOT)),runtime_donor_sha256=hashlib.sha256(runtime_donor.read_bytes()).hexdigest(),
        editable_source=str((out/(role+'.blend')).relative_to(ROOT)),foundation_retained=True,
        runtime=str(runtime.relative_to(ROOT)), complete_body_vertices=len(mesh.vertices),
        source_body_vertices=len(body.data.vertices), facial_vertices=counts,
        exported_meshes=selected, complete_body=True, clothing_masks=False, visual_approved=False)
    assert any('under' in name.lower() or 'foundation' in name.lower() for name in selected), selected
    (out/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    print('ACTIVITY_PERSON', json.dumps(report), flush=True)

for role, donor in DONORS.items(): build(role, donor)
