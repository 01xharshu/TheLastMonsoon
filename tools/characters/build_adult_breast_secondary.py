"""Author adult MPFB profiles and coherent body/garment secondary-motion bones.

Blender --background --python this_file -- --extract-mpfb creates retained
authoring inputs through MPFB. The normal build consumes the completed river
pose-fit source; it never overwrites the original MPFB donor or base pose fit.
"""
import bpy, json, hashlib, sys
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.kdtree import KDTree

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'WorkingAssets/NPCs/river_activity'
INPUT=OUT/'mpfb_adult_breast_profiles.json'
DONOR=ROOT/'WorkingAssets/NPCs/river_woman/river_woman_motion.blend'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def extract_mpfb():
    bpy.ops.preferences.addon_enable(module='bl_ext.blender_org.mpfb')
    from bl_ext.blender_org.mpfb.services.targetservice import TargetService
    from bl_ext.blender_org.mpfb.services.locationservice import LocationService
    from bl_ext.blender_org.mpfb.entities.objectproperties import HumanObjectProperties
    bpy.ops.wm.open_mainfile(filepath=str(DONOR))
    body=bpy.data.objects['village_woman_MakeHuman_body']
    for modifier in body.modifiers:
        if modifier.type in ('MASK','ARMATURE'):modifier.show_viewport=False
    for key in body.data.shape_keys.key_blocks:
        if key.name.startswith('River identity'):key.value=0
    human_group=body.vertex_groups['body'].index
    human={v.index for v in body.data.vertices if any(g.group==human_group and g.weight>.5 for g in v.groups)}
    def points():
        bpy.context.view_layer.update()
        ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
        result=[ev.matrix_world@v.co for v in mesh.vertices];ev.to_mesh_clear()
        return result
    original=points()
    macro=TargetService.get_macro_info_dict_from_basemesh(body)
    assert macro['gender']<.2 and macro['age']>=.5, 'Clearly adult female source required'
    base=float(macro['cupsize']);small=max(.05,base-.12);full=min(.95,base+.12)
    samples=[]
    for value in [base,small,full]:
        HumanObjectProperties.set_value('cupsize',value,entity_reference=body)
        TargetService.reapply_macro_details(body,remove_zero_weight_targets=False)
        samples.append(points())
    weights_path=Path(LocationService.get_mpfb_data('rigs'))/'standard/weights.game_engine_with_breast.json'
    weights=json.loads(weights_path.read_text())
    masks=[dict(weights['weights']['breast_'+side]) for side in ['l','r']]
    rows=[];maximum=0.0
    for index in sorted(human):
        delta_small=samples[1][index]-samples[0][index]
        delta_full=samples[2][index]-samples[0][index]
        left=float(masks[0].get(index,0));right=float(masks[1].get(index,0))
        if max(delta_small.length,delta_full.length,left,right)<1e-8:continue
        maximum=max(maximum,delta_small.length,delta_full.length)
        rows.append([index]+[round(float(v),9) for v in (*original[index],*delta_small,*delta_full,left,right)])
    if not rows or maximum>.05:raise RuntimeError('Unexpected MPFB profile extraction; preserve donor and investigate')
    data={'donor':str(DONOR.relative_to(ROOT)),'donor_sha256':digest(DONOR),'method':'MPFB TargetService.reapply_macro_details; only cupsize changes','adult_age_macro':macro['age'],'macro_baseline':macro,'profiles':[{'id':'smaller','cupsize':small,'mass_scale':.85},{'id':'original','cupsize':base,'mass_scale':1.0},{'id':'fuller','cupsize':full,'mass_scale':1.15}],'row_layout':['source_vertex','rest_x','rest_y','rest_z','small_dx','small_dy','small_dz','full_dx','full_dy','full_dz','left_weight','right_weight'],'rows':rows,'maximum_profile_delta_m':maximum,'weight_source':'MPFB game_engine_with_breast','weight_license':weights.get('license'),'weight_sha256':digest(weights_path)}
    OUT.mkdir(parents=True,exist_ok=True);INPUT.write_text(json.dumps(data,separators=(',',':'))+'\n')
    print('ADULT_MPFB_PROFILE_INPUT',json.dumps({'vertices':len(rows),'cupsize':[small,base,full],'maximum_delta_m':maximum,'source_unchanged':digest(DONOR)==data['donor_sha256']}),flush=True)

def build_secondary():
    relaxed='--relaxed-lower' in sys.argv
    authored=relaxed or '--authored-lower' in sys.argv
    source=OUT/('river_activity_relaxed.blend' if relaxed else 'river_activity_draped.blend' if authored else 'river_activity.blend')
    if (OUT/'fit_checkpoint.json').exists():raise RuntimeError('Complete the base river pose fit before deriving secondary motion')
    if authored:
        report=json.loads((OUT/'lower_fit_manifest.json').read_text())
        if report.get('algorithm')!='stand_skin_clearance_v8' or (OUT/'lower_fit_checkpoint.json').exists() or not report['complete'] or report['source_sha256']!=digest(OUT/'river_activity_draped.blend') or report['base_sha256']!=digest(OUT/'river_activity.blend'):
            raise RuntimeError('Complete and verify the authored lower fit first')
        if relaxed:
            trial=json.loads((OUT/'relaxed_manifest.json').read_text())
            if trial['source_sha256']!=digest(OUT/'river_activity_draped.blend') or trial['pose_sha256']!=digest(OUT/'poses.json') or trial['relaxed_sha256']!=digest(source):raise RuntimeError('Relaxed candidate or its inputs changed')
    data=json.loads(INPUT.read_text())
    if digest(DONOR)!=data['donor_sha256']:raise RuntimeError('MPFB donor changed; re-extract the profile inputs')
    bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.preferences.filepaths.save_version=0
    sys.path.insert(0,str(ROOT/'tools/characters'))
    from river_cotton_finish import finish_upper,integral_border
    cotton_finish=finish_upper(bpy.data.objects['Fitted cotton upper base'])
    border_finish=integral_border(bpy.data.objects['Wrapped sari lower drape'],bpy.data.objects['Sari lower border']) if authored else None
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
    rig.data.pose_position='REST'
    original=[tuple(v.co) for v in body.data.vertices]
    # Verify adding secondary weights does not disturb the accepted base poses.
    sys.path.insert(0,str(ROOT/'tools/characters'))
    from river_cloth_correctives import apply_river_pose
    pose_data=json.loads((OUT/'poses.json').read_text())
    conversion=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
    corrections={name:(conversion@Matrix(rest)@conversion.inverted()).inverted()@rig.data.bones[name].matrix_local for name,rest in pose_data['rest'].items() if name in rig.data.bones}
    animation=rig.animation_data;old_action=animation.action if animation else None
    tracks=[(track,track.mute) for track in animation.nla_tracks] if animation else []
    if animation:animation.action=None
    for track,_ in tracks:track.mute=True
    checked=[body]+[o for o in bpy.data.objects if o.name in ['Fitted cotton upper base','Opaque fitted bra and thong foundation','Wrapped sari lower drape','Sari lower border']]
    canonical=[next(p for p in pose_data['poses'] if p['key'] in ['River fine walk 4 04','River walk 2 04'])]
    canonical.extend(min((p for p in pose_data['poses'] if p['key'].startswith('River cloth')),key=lambda p:abs(p['time']-at)) for at in [17.2,48.25,52.25,65.25])
    def capture(pose):
        rig.data.pose_position='POSE';apply_river_pose(rig,pose['bones'],conversion,corrections)
        for obj in checked:
            for key in obj.data.shape_keys.key_blocks:key.value=1.0 if key.name==pose['key'] else 0.0
        bpy.context.view_layer.update();result={}
        for obj in checked:
            ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
            result[obj.name]=[ev.matrix_world@v.co for v in mesh.vertices];ev.to_mesh_clear()
        return result
    before=[capture(pose) for pose in canonical]
    for obj in checked:
        for key in obj.data.shape_keys.key_blocks:key.value=0
    rig.data.pose_position='REST'
    tree=KDTree(len(data['rows']))
    for index,row in enumerate(data['rows']):tree.insert(Vector(row[1:4]),index)
    tree.balance();bindings={}
    for vertex in body.data.vertices:
        point=body.matrix_world@vertex.co
        _,row_index,distance=tree.find(point)
        if distance<.00002:bindings[vertex.index]=data['rows'][row_index]
    if len(bindings)<500:raise RuntimeError('MPFB/runtime surface mapping is incomplete: '+str(len(bindings)))
    bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
    for side,column in [('l',10),('r',11)]:
        rows=[row for row in data['rows'] if row[column]>.05]
        total=sum(row[column] for row in rows)
        centre=sum((Vector(row[1:4])*row[column] for row in rows),Vector())/total
        centre.y+=.025
        bone=rig.data.edit_bones.new('breast_'+side);bone.parent=rig.data.edit_bones['spine_03']
        bone.head=rig.matrix_world.inverted()@centre
        bone.tail=bone.head+Vector((0,0,.04));bone.use_connect=False
    bpy.ops.object.mode_set(mode='OBJECT');bpy.context.view_layer.update()
    garments=[o for o in bpy.data.objects if o.type=='MESH' and o.get('body_vertex_bindings') is not None]
    for obj in [body]+garments:
        correspondence=list(range(len(body.data.vertices))) if obj==body else list(obj['body_vertex_bindings'])
        for label,column in [('Adult MPFB smaller',4),('Adult MPFB fuller',7)]:
            key=obj.shape_key_add(name=label,from_mix=False)
            for point,basis_point in zip(key.data,obj.data.shape_keys.reference_key.data):point.co=basis_point.co
            inverse=obj.matrix_world.to_3x3().inverted()
            for index,body_index in enumerate(correspondence):
                if body_index in bindings:key.data[index].co+=inverse@Vector(bindings[body_index][column:column+3])
            key.value=0
        parent_group=obj.vertex_groups.get('spine_03')
        groups=[obj.vertex_groups.get('breast_'+side) or obj.vertex_groups.new(name='breast_'+side) for side in ['l','r']]
        if parent_group is None:continue
        for index,body_index in enumerate(correspondence):
            row=bindings.get(body_index)
            if row is None:continue
            old=next((g.weight for g in obj.data.vertices[index].groups if g.group==parent_group.index),0)
            total=row[10]+row[11]
            if total<=0 or old<=0:continue
            transfer=old*min(1.0,total)
            parent_group.add([index],old-transfer,'REPLACE')
            for group,weight in zip(groups,[row[10],row[11]]):
                if weight>0:group.add([index],transfer*weight/total,'REPLACE')
    assert original==[tuple(v.co) for v in body.data.vertices]
    parity=0.0
    for pose,reference in zip(canonical,before):
        current=capture(pose)
        for name,points in current.items():parity=max(parity,max((p-q).length for p,q in zip(points,reference[name])))
    if parity>.00005:raise RuntimeError('Secondary zero-motion pose changed base geometry: '+str(parity))
    for obj in checked:
        for key in obj.data.shape_keys.key_blocks:key.value=0
    for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
    rig.data.pose_position='REST'
    if animation:animation.action=old_action
    for track,muted in tracks:track.mute=muted
    target=OUT/('river_activity_secondary_relaxed.blend' if relaxed else 'river_activity_secondary.blend');bpy.ops.wm.save_as_mainfile(filepath=str(target))
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
    for obj in bpy.data.objects:
        if obj.type=='MESH' and not obj.get('activity_source_only',False):obj.select_set(True)
    rig.data.pose_position='POSE';rig.animation_data_create();rig.animation_data.action=bpy.data.actions.get('idle');bpy.context.scene.frame_set(1)
    runtime=ROOT/('characters/npcs/activity_people/river_activity_secondary_relaxed.glb' if relaxed else 'characters/npcs/activity_people/river_activity_secondary.glb')
    bpy.ops.export_scene.gltf(filepath=str(runtime),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,export_cameras=False,export_lights=False,export_yup=True,export_skins=True,export_all_influences=True,export_apply=False,export_morph_normal=True,export_morph_tangent=False,export_vertex_color='ACTIVE')
    report={'integral_border':border_finish,'cotton_edge_finish':cotton_finish,'source':str(target.relative_to(ROOT)),'source_sha256':digest(target),'runtime':str(runtime.relative_to(ROOT)),'runtime_sha256':digest(runtime),'base_pose_fit':str(source.relative_to(ROOT)),'base_pose_fit_sha256':digest(source),'mpfb_profile_inputs':str(INPUT.relative_to(ROOT)),'profiles':data['profiles'],'mapped_body_vertices':len(bindings),'complete_body_vertices':len(original),'base_rest_coordinates_unchanged':True,'same_weights_body_foundation_outerwear':True,'zero_motion_max_delta_m':parity,'secondary_bones':['breast_l','breast_r'],'clothing_support':.72,'visual_approved':False}
    (OUT/('secondary_relaxed_manifest.json' if relaxed else 'secondary_manifest.json')).write_text(json.dumps(report,indent=2)+'\n')
    print('ADULT_SECONDARY_ASSET',json.dumps(report),flush=True)

if '--extract-mpfb' in sys.argv:extract_mpfb()
else:build_secondary()
