"""Build distinct clothed street identities from retained complete MPFB donors."""
import bpy, bmesh, json, math, sys, numpy as np
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/characters'))
from whole_body_contract import retain_complete_body

def supported_street_pallu(rig):
    """Reuse the fitted blouse's triangles and weights for its outer panel."""
    from mathutils import Vector
    blouse=bpy.data.objects['Fitted cotton upper base'];old=bpy.data.objects['Woven sari pallu over blouse']
    blouse.data.calc_loop_triangles()
    selected=[]
    for triangle in blouse.data.loop_triangles:
        point=sum((blouse.data.vertices[i].co for i in triangle.vertices),Vector())/3
        if .84<point.z<1.245 and point.y<.005 and abs(point.x-(.14-(point.z-.85)*.29/.39))<.105:selected.append(tuple(triangle.vertices))
    ids=sorted({i for face in selected for i in face});mapping={i:j for j,i in enumerate(ids)}
    normals=[Vector() for vertex in blouse.data.vertices]
    for triangle in blouse.data.loop_triangles:
        a,b,c=[blouse.data.vertices[i].co for i in triangle.vertices];normal=(b-a).cross(c-a)
        for i in triangle.vertices:normals[i]+=normal
    mesh=bpy.data.meshes.new('Street blouse-supported sari panel')
    mesh.from_pydata([blouse.data.vertices[i].co+normals[i].normalized()*.018 for i in ids],[],[tuple(mapping[i] for i in face) for face in selected]);mesh.update()
    panel=bpy.data.objects.new('Street outer pallu',mesh);bpy.context.collection.objects.link(panel)
    panel.parent=blouse.parent;panel.matrix_parent_inverse=blouse.matrix_parent_inverse.copy();panel.matrix_basis=blouse.matrix_basis.copy()
    for group in blouse.vertex_groups:panel.vertex_groups.new(name=group.name)
    for j,i in enumerate(ids):
        for group in blouse.data.vertices[i].groups:panel.vertex_groups[group.group].add([j],group.weight,'REPLACE')
    panel.modifiers.new('Original MPFB rig','ARMATURE').object=rig
    mesh.materials.append(old.data.materials[0])
    for face in mesh.polygons:face.use_smooth=True
    bpy.data.objects.remove(old,do_unlink=True);panel.name='Woven sari pallu over blouse'
    panel['construction']='Separate outer cotton panel; fitted blouse support and skin weights, 18 mm source clearance'

def fit_female_rest(rig,body):
    """Street actors use rest garments, not the river action morph timeline."""
    from river_surface_binding import bind_surface,apply_surface
    from river_coherent_cloth import fit_key
    from purpose_cloth_volume import VolumeSurface
    masks=[(modifier,modifier.show_viewport) for modifier in body.modifiers if modifier.type=='MASK']
    for modifier,_ in masks:modifier.show_viewport=False
    bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
    mesh=bpy.data.meshes.new_from_object(body.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
    try:
        group=body.vertex_groups['body'].index
        human={vertex.index for vertex in body.data.vertices if any(value.group==group and value.weight>.5 for value in vertex.groups)}
        mesh.calc_loop_triangles()
        points=[body.matrix_world@vertex.co for vertex in mesh.vertices]
        normals=[(body.matrix_world.to_3x3()@vertex.normal).normalized() for vertex in mesh.vertices]
        faces=[tuple(triangle.vertices) for triangle in mesh.loop_triangles if all(index in human for index in triangle.vertices)]
        tree=VolumeSurface.FromPolygons(points,faces,all_triangles=True,strict=True)
        for name in ['Fitted cotton upper base','Opaque fitted bra and thong foundation']:
            obj=bpy.data.objects[name]
            if obj.data.shape_keys:obj.shape_key_clear()
            key=obj.shape_key_add(name='Basis')
            bind_surface(obj,body,mesh,human)
            apply_surface(rig,obj,key,points,normals)
            fit_key(rig,obj,tree,key,reset_key=False)
            # Preserve the chest bridge between clothing layers. Rebinding to
            # skin alone put the pallu behind the blouse's bridge, making a
            # continuous panel look torn in the actual renderer.
            if name!='Opaque fitted bra and thong foundation':
                def ease(a,b,value):
                    t=max(0,min(1,(value-a)/(b-a)));return t*t*(3-2*t)
                for fitted in key.data:
                    point=obj.matrix_world@fitted.co
                    if point.y>=-.025:continue
                    vertical=ease(.95,.99,point.z)*(1-ease(1.17,1.23,point.z))
                    lateral=1-ease(.20,.27,abs(point.x))
                    strength=vertical*lateral
                    front=-.255 if name=='Woven sari pallu over blouse' else -.205
                    point.y=min(point.y,point.y*(1-strength)+front*strength)
                    fitted.co=obj.matrix_world.inverted()@point
            # With morph export disabled, glTF reads the mesh's raw vertices.
            # Keep those identical to the fitted Basis instead of exporting
            # the unfitted donor mesh beneath the editable fitted key.
            for vertex,fitted in zip(obj.data.vertices,key.data):vertex.co=fitted.co
        supported_street_pallu(rig)
    finally:
        bpy.data.meshes.remove(mesh)
        for modifier,enabled in masks:modifier.show_viewport=enabled

def trim_work_sleeves(obj,prefixes,limit):
    """Finish a work-shirt cuff on the donor cloth's deform-weight contour."""
    indices={g.index for g in obj.vertex_groups if g.name.startswith(prefixes)}
    bm=bmesh.new();bm.from_mesh(obj.data);deform=bm.verts.layers.deform.verify()
    def weight(vertex):return sum(vertex[deform].get(i,0) for i in indices)
    boundary=set()
    for edge in list(bm.edges):
        a,b=edge.verts;wa,wb=weight(a),weight(b)
        if (wa-limit)*(wb-limit)>=0:continue
        t=(limit-wa)/(wb-wa);ga=dict(a[deform]);gb=dict(b[deform])
        _,vertex=bmesh.utils.edge_split(edge,a,t)
        for group in ga.keys()|gb.keys():vertex[deform][group]=(1-t)*ga.get(group,0)+t*gb.get(group,0)
        boundary.add(vertex)
    for face in list(bm.faces):
        cuts=[v for v in face.verts if v in boundary]
        if len(cuts)==2 and len(face.verts)>3:bmesh.utils.face_split(face,cuts[0],cuts[1])
    bmesh.ops.delete(bm,geom=[f for f in bm.faces if sum(weight(v) for v in f.verts)/len(f.verts)>limit+1e-6],context='FACES')
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
    bm.to_mesh(obj.data);bm.free();obj.data.update()

def build(sex, index, workwear=False):
    donor = ('river_woman/river_woman_motion.blend' if sex == 'female' else
             f'street_residents/{"merchant" if index % 2 == 0 else "landowner"}/{"merchant" if index % 2 == 0 else "landowner"}.blend')
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'WorkingAssets/NPCs' / donor))
    bpy.context.preferences.filepaths.save_version = 0
    rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    rig.data.pose_position = 'REST'
    rig.animation_data_clear()
    from mathutils import Matrix
    for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    body = next(o for o in bpy.data.objects if o.type == 'MESH' and 'MakeHuman_body' in o.name)
    retain_complete_body(body)
    # A height-only donor foundation included the lowered rest-pose hands.
    # Trim that clothing only; retain the complete original MPFB skin beneath.
    for garment in bpy.data.objects:
        if garment.type != 'MESH' or not garment.name.startswith('Street opaque foundation'): continue
        arms={group.index for group in garment.vertex_groups if group.name.startswith(('hand_', 'thumb_', 'index_', 'middle_', 'ring_', 'pinky_', 'lowerarm_', 'upperarm_', 'clavicle_'))}
        bm=bmesh.new();bm.from_mesh(garment.data)
        deform=bm.verts.layers.deform.active
        if deform:
            rejected=[face for face in bm.faces if any(sum(weight for index,weight in vertex[deform].items() if index in arms)>.15 for vertex in face.verts)]
            bmesh.ops.delete(bm,geom=rejected,context='FACES')
            loose=[vertex for vertex in bm.verts if not vertex.link_faces]
            if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
        bm.to_mesh(garment.data);bm.free();garment.data.update()
    # Apply small, smooth facial changes to every shape key, preserving topology,
    # physique keys, eyes, original skin weights and the complete donor anatomy.
    vertices = body.data.shape_keys.key_blocks if body.data.shape_keys else [None]
    jaw = [-.15, .11, -.045, .17][index]
    nose = [.009, -.004, .013, .002][index]
    cheek = [.07, -.055, .13, -.09][index]
    head = rig.data.bones['head'].head_local.z
    masks=[(m,m.show_viewport) for m in body.modifiers if m.type=='MASK']
    for m,_ in masks:m.show_viewport=False
    bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    evaluated=bpy.data.meshes.new_from_object(body.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
    deltas=[]
    for vertex in evaluated.vertices:
        point=body.matrix_world@vertex.co
        original=point.copy()
        if point.z>head-.09:
            low=math.exp(-((point.z-(head-.035))/.030)**2)
            mid=math.exp(-((point.z-(head+.025))/.020)**2)
            point.x*=1+jaw*low+cheek*mid
            front=max(0,min(1,(-point.y-.025)/.05))
            point.y-=nose*math.exp(-(point.x/.025)**2)*front*mid
        deltas.append(body.matrix_world.to_3x3().inverted()@(point-original))
    bpy.data.meshes.remove(evaluated)
    for m,enabled in masks:m.show_viewport=enabled
    for key in vertices:
        for i,vertex in enumerate(key.data if key else body.data.vertices):vertex.co+=deltas[i]
    # Whole-character horizontal proportions change together with the MPFB rig,
    # all physique keys, garments, eyes and hair. No covered body surface is cut.
    width=[.96,1.035,1.075,.985][index]
    for obj in bpy.data.objects:
        if obj.type!='MESH':continue
        blocks=obj.data.shape_keys.key_blocks if obj.data.shape_keys else [None]
        inverse=obj.matrix_world.inverted()
        for block in blocks:
            for vertex in (block.data if block else obj.data.vertices):
                point=obj.matrix_world@vertex.co;point.x*=width;vertex.co=inverse@point
    bpy.ops.object.mode_set(mode='OBJECT') if bpy.context.object and bpy.context.object.mode!='OBJECT' else None
    bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
    inverse=rig.matrix_world.inverted()
    for bone in rig.data.edit_bones:
        for endpoint in ['head','tail']:
            point=rig.matrix_world@getattr(bone,endpoint);point.x*=width;setattr(bone,endpoint,inverse@point)
    bpy.ops.object.mode_set(mode='OBJECT')
    for slot, original_material in enumerate(body.data.materials):
        mat=original_material.copy();body.data.materials[slot]=mat
        if not mat.use_nodes:continue
        node=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
        if node:
            tint=([(.61,.42,.28),(.76,.55,.39),(.48,.31,.20),(.67,.47,.32)] if sex=='female' else [(.91,.94,.97),(1.06,1.04,1.01),(.84,.88,.93),(.97,.97,.95)])[index]
            source_node=next((n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image and 'diffuse' in n.image.name.lower()),None)
            if source_node is None:
                skin=next((image for image in bpy.data.images if 'darkskinned' in image.name.lower() and 'diffuse' in image.name.lower()),None)
                if skin:
                    source_node=mat.node_tree.nodes.new('ShaderNodeTexImage');source_node.image=skin
            if source_node:
                original=source_node.image
                pixels=np.empty(len(original.pixels),dtype=np.float32);original.pixels.foreach_get(pixels)
                pixels.reshape((-1,4))[:,:3]*=np.array(tint,dtype=np.float32)
                image=bpy.data.images.new(f'Indian_{sex}_{index}_skin',width=original.size[0],height=original.size[1])
                image.pixels.foreach_set(pixels);image.pack();source_node.image=image
                for link in list(node.inputs['Base Color'].links):mat.node_tree.links.remove(link)
                mat.node_tree.links.new(source_node.outputs['Color'],node.inputs['Base Color'])
            else:node.inputs['Base Color'].default_value=(*tint,1)
    if sex=='female':
        fit_female_rest(rig,body)
        hair=bpy.data.objects.get('Farmer_hair')
        if hair:
            # Reshape the retained MPFB hair mesh, preserving its scalp and
            # commercial source. The body and its topology remain untouched.
            if index==1:
                for vertex in hair.data.vertices:
                    if vertex.co.z<1.30:vertex.co.z=1.30+(vertex.co.z-1.30)*.58
            elif index==2:
                head_group=hair.vertex_groups.get('head')
                for vertex in hair.data.vertices:
                    if vertex.co.z>=1.30:continue
                    length=1.30-vertex.co.z
                    theta=length/.36*math.pi*2
                    vertex.co.x+=.042*math.sin(theta)
                    vertex.co.y=.080+(vertex.co.y-.080)*.4+.042*(1-math.cos(theta))
                    vertex.co.z=1.30+.045*math.sin(theta*.5)
                    for group in hair.vertex_groups:group.remove([vertex.index])
                    head_group.add([vertex.index],1,'REPLACE')
            elif index==3:
                for vertex in hair.data.vertices:
                    if vertex.co.z<1.30:vertex.co.x+=.10*min(1,(1.30-vertex.co.z)/.25)
            hair['style']=['long center braid','short braid','coiled back bun','side braid'][index]
            hair.data.update()
    palettes = ([(.31,.115,.105),(.12,.19,.29),(.25,.28,.13),(.39,.23,.11)] if sex == 'female' else
                [(.11,.18,.23),(.38,.30,.20),(.19,.25,.16),(.35,.18,.13)])
    for mat in bpy.data.materials:
        label = mat.name.lower()
        if not any(word in label for word in ['plain woven', 'cotton blouse', 'waistcoat', 'ivory coat']): continue
        color = palettes[index]
        if 'blouse' in label: color = [(.30,.25,.11),(.42,.32,.22),(.36,.18,.14),(.23,.25,.16)][index]
        mat.diffuse_color = (*color, 1)
        if mat.use_nodes:
            node = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
            if node:
                for link in list(node.inputs['Base Color'].links):mat.node_tree.links.remove(link)
                node.inputs['Base Color'].default_value = (*color, 1)
    if workwear:
        upper=bpy.data.objects.get('Fitted cotton upper base')
        if upper and index<3:
            trim_work_sleeves(upper,('upperarm_','lowerarm_','hand_') if index==0 else ('lowerarm_','hand_'),.25 if index<2 else .05)
        # Workers retain the donor anatomy and foundation; change the outfit only.
        for obj in list(bpy.data.objects):
            if obj.name.startswith('Bordered shoulder shawl') or (index%2==0 and obj.name.startswith('Fitted turban')):
                bpy.data.objects.remove(obj,do_unlink=True)
        for mat in bpy.data.materials:
            if any(word in mat.name.lower() for word in ['waistcoat','ivory coat','woven cotton','gold border']):
                color=[(.36,.31,.23),(.25,.28,.21),(.43,.37,.28),(.28,.25,.21)][index]
                mat.diffuse_color=(*color,1)
                if mat.use_nodes:
                    node=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
                    if node:
                        for link in list(node.inputs['Base Color'].links):mat.node_tree.links.remove(link)
                        node.inputs['Base Color'].default_value=(*color,1);node.inputs['Roughness'].default_value=.97
    slug = f'{"workman" if workwear else sex}_{index+1:02d}'
    out = ROOT / 'WorkingAssets/NPCs/indian_street_variants' / slug
    out.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(out / f'{slug}.blend'))
    # Bake only helper exclusion and existing physique; never a clothing mask.
    dg = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(body.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    cutout = bpy.data.objects.new(body.name + '_export_cutout', mesh)
    bpy.context.collection.objects.link(cutout)
    for group in body.vertex_groups: cutout.vertex_groups.new(name=group.name)
    cutout.parent = rig
    cutout.matrix_parent_inverse = body.matrix_parent_inverse.copy()
    cutout.matrix_basis = body.matrix_basis.copy()
    cutout.modifiers.new('Original MPFB rig', 'ARMATURE').object = rig
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    for obj in bpy.data.objects:
        if obj.type == 'MESH' and obj != body: obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    runtime = ROOT / 'characters/npcs/street_residents' / f'{slug}.glb'
    bpy.ops.export_scene.gltf(filepath=str(runtime), export_format='GLB', use_selection=True,
                             export_animations=False, export_skins=True, export_all_influences=True,
                             export_cameras=False, export_lights=False, export_morph=False)
    report = dict(identity=slug, donor=donor, complete_body_vertices=len(body.data.vertices),
                  facial_changes=dict(jaw=jaw,nose=nose,cheek=cheek), whole_character_width=width,
                  runtime=str(runtime.relative_to(ROOT)), wardrobe=['sleeveless cotton work shirt','elbow sleeve cotton work shirt','short sleeve cotton work shirt','long sleeve cotton work shirt'][index] if workwear else ('cotton sari and blouse' if sex=='female' else 'street formal'), hair_style=['long center braid','short braid','coiled back bun','side braid'][index] if sex=='female' else ('uncovered' if workwear and index%2==0 else 'turban'), visual_approved=False)
    (out / 'manifest.json').write_text(json.dumps(report, indent=2)+'\n')
    print('INDIAN_STREET_VARIANT', json.dumps(report), flush=True)

indices=[int(sys.argv[sys.argv.index('--identity-index')+1])] if '--identity-index' in sys.argv else range(4)
if '--workwear-only' not in sys.argv:
    for sex in (['female'] if '--female-only' in sys.argv else (['male'] if '--male-only' in sys.argv else ['female','male'])):
        for index in indices: build(sex, index)
if '--female-only' not in sys.argv:
    for index in indices: build('male',index,True)
