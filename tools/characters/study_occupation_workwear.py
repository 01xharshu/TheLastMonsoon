"""Create an isolated MPFB-to-activity workwear study; never edits live assets.

The output must be a new .blend in the OS temporary directory. This is a
correspondence experiment, not a production garment or fit certification.
"""
import argparse
import sys
import tempfile
from pathlib import Path
import bpy
from mathutils.kdtree import KDTree
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools/characters'))
from purpose_cloth_volume import inside_surface, VolumeSurface
from river_coherent_cloth import fit_key
args = argparse.ArgumentParser()
args.add_argument('--output', required=True, type=Path)
args.add_argument('--shirt-hem',type=float,help='Trim source shirt at this world-space height before transfer')
args.add_argument('--subdivide-foundation',action='store_true',help='One fabric-only subdivision before pose fitting')
args.add_argument('--cloth-foundation',action='store_true',help='Fit seated foundation through gradual cloth collision')
args.add_argument('--smooth-transfer',action='store_true',help='Blend eight body correspondences against the target surface')
args.add_argument('--exact-layers',action='store_true',help='Use seam-aware self repair and exact inner/outer triangle separation')
args.add_argument('--layered-fit',action='store_true',help='Fit foundation, trousers and shirt in order')
args.add_argument('--pattern-foundation',action='store_true',help='Disposable foundation derived from authored MPFB lower-garment pattern')
args.add_argument('--visual-probe', action='store_true', help='Use explicit wider outer/foundation bounds only for disposable silhouette inspection')
args = args.parse_args(sys.argv[sys.argv.index('--') + 1:])
if args.exact_layers and not args.layered_fit:raise ValueError('Exact layer repair requires --layered-fit')
if args.layered_fit and not args.pattern_foundation:raise ValueError('Ordered fitting requires --pattern-foundation')
out = args.output.expanduser().resolve()
tmp = Path(tempfile.gettempdir()).resolve()
if not out.is_relative_to(tmp) or out.suffix != '.blend' or out.exists():
    raise ValueError('Output must be a new .blend under the OS temporary directory')
source = ROOT/'WorkingAssets/NPCs/village_farmer/village_farmer_mpfb.blend'
target = ROOT/'WorkingAssets/NPCs/activity_people/artisan/artisan.blend'
asset = ROOT/'WorkingAssets/NPCs/occupation_wardrobe/source_patterns/male_casualsuit02/male_casualsuit02.mhclo'
if not asset.is_file():
    asset = Path.home()/'Library/Application Support/Blender/5.2/extensions/.user/blender_org/mpfb/data/clothes/male_casualsuit02/male_casualsuit02.mhclo'
if not all(p.is_file() for p in (source,target,asset)): raise FileNotFoundError('Missing source, target, or MPFB workwear')
bpy.ops.preferences.addon_enable(module='bl_ext.blender_org.mpfb')
from bl_ext.blender_org.mpfb.services.humanservice import HumanService
bpy.ops.wm.open_mainfile(filepath=str(source))
body = bpy.data.objects['village_farmer_MakeHuman_body']
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
rig.data.pose_position = 'REST'
bpy.context.view_layer.update()
cloth = HumanService.add_mhclo_asset(str(asset),body,asset_type='Clothes',subdiv_levels=0)
bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
def points(obj):
    evaluated = obj.evaluated_get(dg)
    mesh = evaluated.to_mesh()
    values = [evaluated.matrix_world @ v.co for v in mesh.vertices]
    faces = [tuple(p.vertices) for p in mesh.polygons]
    evaluated.to_mesh_clear()
    return values, faces
source_points, _ = points(body)
cloth_points, cloth_faces = points(cloth)
if len(cloth_points) != len(cloth.data.vertices):
    raise RuntimeError('Unexpected workwear topology after evaluation')
source_weights = [[(cloth.vertex_groups[g.group].name, g.weight) for g in vertex.groups]
                  for vertex in cloth.data.vertices]
# Keep the separate upper and lower components as a coordinated outfit.
# Styling remains subject to historical and visual review.
parents=list(range(len(cloth_points)))
def root(i):
    while parents[i]!=i:
        parents[i]=parents[parents[i]];i=parents[i]
    return i
for edge in cloth.data.edges:
    parents[root(edge.vertices[0])]=root(edge.vertices[1])
components={}
for i,p in enumerate(cloth_points):components.setdefault(root(i),[]).append(i)
upper=[ids for ids in components.values() if min(cloth_points[i].z for i in ids)>.70 and max(cloth_points[i].z for i in ids)>1.35]
if not upper:raise RuntimeError('No independent short-sleeve component found')
lower=[ids for ids in components.values() if min(cloth_points[i].z for i in ids)<.15 and max(cloth_points[i].z for i in ids)<1.1]
if not lower:raise RuntimeError('No independent trouser component found')
upper_ids=max(upper,key=len)
selected=upper_ids+max(lower,key=len);mapping={old:new for new,old in enumerate(selected)}
cloth_faces=[tuple(mapping[i] for i in face) for face in cloth_faces if all(i in mapping for i in face)]
cloth_points=[cloth_points[i] for i in selected]
source_weights=[source_weights[i] for i in selected]
if args.shirt_hem is not None:
    if not .85 <= args.shirt_hem <= 1.05:
        raise ValueError('Shirt hem must stay within the retained adult waist region')
    import bmesh
    old_upper_count = len(upper_ids)
    upper_faces = [face for face in cloth_faces if all(i < old_upper_count for i in face)]
    lower_faces = [face for face in cloth_faces if all(i >= old_upper_count for i in face)]
    pattern_mesh = bpy.data.meshes.new('Occupation shirt hem pattern')
    pattern_mesh.from_pydata(cloth_points[:old_upper_count], [], upper_faces)
    pattern_mesh.update()
    pattern = bpy.data.objects.new('Occupation shirt hem pattern', pattern_mesh)
    bpy.context.collection.objects.link(pattern)
    for i, assignments in enumerate(source_weights[:old_upper_count]):
        for bone_name, weight in assignments:
            group = pattern.vertex_groups.get(bone_name) or pattern.vertex_groups.new(name=bone_name)
            group.add([i], weight, 'REPLACE')
    bm = bmesh.new()
    bm.from_mesh(pattern_mesh)
    bmesh.ops.bisect_plane(
        bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces),
        plane_co=Vector((0, 0, args.shirt_hem)), plane_no=Vector((0, 0, 1)),
        clear_inner=True, clear_outer=False, dist=.000001,
    )
    loose = [vertex for vertex in bm.verts if not vertex.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bm.to_mesh(pattern_mesh)
    bm.free()
    pattern_mesh.update()
    trimmed_points = [vertex.co.copy() for vertex in pattern_mesh.vertices]
    trimmed_weights = [[(pattern.vertex_groups[group.group].name, group.weight)
                        for group in vertex.groups] for vertex in pattern_mesh.vertices]
    if not trimmed_points or any(not assignments for assignments in trimmed_weights):
        raise RuntimeError('Trimmed shirt lost geometry or skin weights')
    new_upper_count = len(trimmed_points)
    cloth_points = trimmed_points + cloth_points[old_upper_count:]
    source_weights = trimmed_weights + source_weights[old_upper_count:]
    cloth_faces = [tuple(face.vertices) for face in pattern_mesh.polygons] + [
        tuple(i - old_upper_count + new_upper_count for i in face) for face in lower_faces
    ]
    upper_ids = list(range(new_upper_count))
    print('OCCUPATION_SHIRT_HEM', args.shirt_hem, old_upper_count, new_upper_count, flush=True)

source_tree = KDTree(len(source_points))
for i,p in enumerate(source_points): source_tree.insert(p,i)
source_tree.balance()
# Opening a different source preserves these Python-side arrays only.
bpy.ops.wm.open_mainfile(filepath=str(target))
bpy.context.preferences.filepaths.save_version = 0
body = bpy.data.objects['artisan_complete_MakeHuman_body']
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
rig.data.pose_position = 'REST'
bpy.context.view_layer.update()
target_points = [body.matrix_world @ v.co for v in body.data.vertices]
target_tree = KDTree(len(target_points))
for i,p in enumerate(target_points): target_tree.insert(p,i)
target_tree.balance()
body.data.calc_loop_triangles()
target_surface=BVHTree.FromPolygons(target_points,[tuple(t.vertices) for t in body.data.loop_triangles],all_triangles=True)
# Map through nearby body points, retaining the original garment clearance.
# Distances are reported, not used as a substitute for contact checks.
vertices=[]; weights=[]; max_delta=0.0
for garment_index,p in enumerate(cloth_points):
    if args.smooth_transfer:
        displacement=Vector();total=0.0
        for source_p,_,distance in source_tree.find_n(p,8):
            target_p,_,_,delta=target_surface.find_nearest(source_p)
            weight=1.0/max(.0001,distance*distance)
            displacement+=(target_p-source_p)*weight;total+=weight
            max_delta=max(max_delta,delta)
        displacement/=total
    else:
        source_p, _, _ = source_tree.find(p)
        target_p, target_index, delta = target_tree.find(source_p)
        max_delta=max(max_delta,delta)
        displacement=target_p-source_p
    vertices.append(rig.matrix_world.inverted() @ (p + displacement))
    weights.append([(name,weight) for name,weight in source_weights[garment_index] if name in rig.data.bones])
mesh=bpy.data.meshes.new('Workwear transfer study')
mesh.from_pydata(vertices,[],cloth_faces);mesh.update()
obj=bpy.data.objects.new('Workwear transfer study',mesh);bpy.context.collection.objects.link(obj);obj.parent=rig
for index,groups in enumerate(weights):
    for name,weight in groups:
        (obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)).add([index],weight,'REPLACE')
obj.modifiers.new('Activity rig','ARMATURE').object=rig
for face in mesh.polygons: face.use_smooth=True
mesh.calc_loop_triangles()
from river_upper_self_fit import self_hits
for part,faces in [('shirt',[tuple(t.vertices) for t in mesh.loop_triangles if all(i<len(upper_ids) for i in t.vertices)]),('trousers',[tuple(t.vertices) for t in mesh.loop_triangles if all(i>=len(upper_ids) for i in t.vertices)])]:
    print('OCCUPATION_TRANSFER_SELF',part,'source',self_hits(cloth_points,faces),'mapped',self_hits(vertices,faces),flush=True)
# Rest-pose rejection-screen correction. Limit all displacement and preserve
# topology; this is an experiment, not proof that deformed poses fit.
body.data.calc_loop_triangles()
surface=VolumeSurface.FromPolygons(target_points,[tuple(t.vertices) for t in body.data.loop_triangles],all_triangles=True,strict=True)
initial=[v.co.copy() for v in mesh.vertices]
max_fit=0.0
for iteration in range(5):
    mesh.calc_loop_triangles()
    world=[rig.matrix_world @ v.co for v in mesh.vertices]
    samples=[((i,),p) for i,p in enumerate(world)]
    samples += [(tuple(t.vertices),sum((world[i] for i in t.vertices),Vector())/3.0) for t in mesh.loop_triangles]
    corrections=[Vector() for _ in world]; counts=[0 for _ in world]
    for indices,p in samples:
        if not inside_surface(surface,p): continue
        nearest=surface.find_nearest(p)
        if not nearest or nearest[3] <= .001: continue
        point,normal,_,distance=nearest
        delta=point+normal.normalized()*.004-p
        if delta.length>.04: continue
        for i in indices: corrections[i]+=delta;counts[i]+=1
    if not any(counts): break
    for i,vertex in enumerate(mesh.vertices):
        if counts[i]:
            correction=rig.matrix_world.to_3x3().inverted() @ (corrections[i]/counts[i])
            proposed=vertex.co+correction
            if (proposed-initial[i]).length<=.04: vertex.co=proposed
            max_fit=max(max_fit,(vertex.co-initial[i]).length)
    mesh.update()
# A fabric-pattern control separates inherited skin-shell fold defects from
# outer-cloth fitting. The original layer stays recoverable in this temp study.
if args.pattern_foundation:
    original_foundation=bpy.data.objects['Street opaque foundation']
    original_foundation.name='Retained original foundation reference'
    original_foundation.hide_render=True;original_foundation.hide_set(True)
    lower_start=len(upper_ids)
    chosen=[i for i,v in enumerate(mesh.vertices) if i>=lower_start and (rig.matrix_world@v.co).z>.72]
    remap={old:new for new,old in enumerate(chosen)}
    faces=[tuple(remap[i] for i in face.vertices) for face in mesh.polygons if all(i in remap for i in face.vertices)]
    used={i for face in faces for i in face}
    if len(used)!=len(chosen):raise RuntimeError('Foundation pattern has loose cropped vertices')
    fitted=[]
    for i in chosen:
        point=rig.matrix_world@mesh.vertices[i].co
        # Keep the complete authored fabric bridge and ease. Nearest-skin
        # projection turned both seam and hip folds back into a skin shell.
        fitted.append(rig.matrix_world.inverted()@point)
    data=bpy.data.meshes.new('Authored MPFB foundation pattern')
    data.from_pydata(fitted,[],faces);data.update()
    foundation=bpy.data.objects.new('Street opaque foundation',data)
    bpy.context.collection.objects.link(foundation);foundation.parent=rig
    for material in original_foundation.data.materials:data.materials.append(material)
    for new,old in enumerate(chosen):
        for name,weight in weights[old]:
            (foundation.vertex_groups.get(name) or foundation.vertex_groups.new(name=name)).add([new],weight,'REPLACE')
    foundation.modifiers.new('Original MPFB rig','ARMATURE').object=rig
    for face in data.polygons:face.use_smooth=True
    foundation['occupation_pattern_indices'] = [i - lower_start for i in chosen]
    print('OCCUPATION_PATTERN_FOUNDATION',len(fitted),len(faces),flush=True)

obj['occupation_upper_vertex_count']=len(upper_ids)
if args.layered_fit:
    from occupation_layered_fit import fit
    fit(rig,body,obj,bpy.data.objects['Street opaque foundation'],len(upper_ids),args.visual_probe,args.exact_layers,args.cloth_foundation,args.subdivide_foundation)
    for name in ('Activity cotton shirt','Activity cotton trousers'):
        old=bpy.data.objects.get(name)
        if old:old.hide_render=True;old.hide_set(True)
    obj['status']='UNAPPROVED ordered layer study; real motion and rendered acceptance required'
    obj['source_asset']='MPFB male_casualsuit02, CC0'
    bpy.ops.wm.save_as_mainfile(filepath=str(out))
    print('OCCUPATION_ORDERED_SAVED',str(out),flush=True)
    raise SystemExit(0)

# Fit the seated screening pose back into bind space using the actual blended
# armature transform. Reject excessive displacements rather than deforming the
# candidate without bound. Later checks must exercise the real work graph.
obj.shape_key_add(name='Basis')
basis=obj.data.shape_keys.key_blocks['Basis']
before_rest=[v.co.copy() for v in basis.data]
bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
rest_skin=body.evaluated_get(deps);rest_mesh=rest_skin.to_mesh();rest_mesh.calc_loop_triangles()
rest_body=VolumeSurface.FromPolygons([rest_skin.matrix_world @ v.co for v in rest_mesh.vertices],
                              [tuple(t.vertices) for t in rest_mesh.loop_triangles],all_triangles=True,strict=True)
rest_inner=bpy.data.objects['Street opaque foundation'].evaluated_get(deps)
rest_inner_mesh=rest_inner.to_mesh();rest_inner_mesh.calc_loop_triangles()
rest_foundation=BVHTree.FromPolygons([rest_inner.matrix_world @ v.co for v in rest_inner_mesh.vertices],
                                    [tuple(t.vertices) for t in rest_inner_mesh.loop_triangles],all_triangles=True)
fit_key(rig,obj,rest_body,basis,reset_key=False,foundation=rest_foundation,minimum_clearance_m=.002,jacobi=True)
rest_fit=max((basis.data[i].co-before_rest[i]).length for i in range(len(before_rest)))
print('OCCUPATION_REST_EXTREMES',[(i,tuple(round(v,4) for v in before_rest[i]),round((basis.data[i].co-before_rest[i]).length*1000,3)) for i in sorted(range(len(before_rest)),key=lambda i:(basis.data[i].co-before_rest[i]).length,reverse=True)[:5]],flush=True)
rest_skin.to_mesh_clear();rest_inner.to_mesh_clear()
if rest_fit>.05:raise RuntimeError('Rest foundation correction %.3fmm exceeded 50mm' % (rest_fit*1000))
before_seat=[v.co.copy() for v in basis.data]
seated_key=obj.shape_key_add(name='Study seated correction')
seated_key.value=1.0
rig.data.pose_position='POSE'
for bone in rig.pose.bones: bone.matrix_basis=Matrix.Identity(4)
for side in ['l','r']:
    for name,angle in [('thigh_'+side,-1.35),('calf_'+side,1.5),('upperarm_'+side,-.45),('lowerarm_'+side,-.85)]:
        bone=rig.pose.bones.get(name)
        if bone:
            axis=bone.bone.matrix_local.to_3x3().inverted() @ Vector((1,0,0))
            bone.rotation_mode='QUATERNION';bone.rotation_quaternion=Quaternion(axis.normalized(),angle)
bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
skin=body.evaluated_get(deps);skinmesh=skin.to_mesh();skinmesh.calc_loop_triangles()
seat_body=VolumeSurface.FromPolygons([skin.matrix_world @ v.co for v in skinmesh.vertices],
                               [tuple(t.vertices) for t in skinmesh.loop_triangles],all_triangles=True,strict=True)
foundation_obj=bpy.data.objects['Street opaque foundation']
if not foundation_obj.data.shape_keys:foundation_obj.shape_key_add(name='Basis')
foundation_basis=foundation_obj.data.shape_keys.key_blocks['Basis']
foundation_key=foundation_obj.shape_key_add(name='Study seated foundation')
foundation_key.value=1.0
foundation_limit=(.06 if args.pattern_foundation else .035) if args.visual_probe else .02
bone_transforms={g.index:bone.matrix@bone.bone.matrix_local.inverted() for g in foundation_obj.vertex_groups if (bone:=rig.pose.bones.get(g.name))}
for iteration in range(3):
    bpy.context.view_layer.update();fd=foundation_obj.evaluated_get(bpy.context.evaluated_depsgraph_get());fm=fd.to_mesh()
    fpoints=[fd.matrix_world@v.co for v in fm.vertices];fd.to_mesh_clear()
    if iteration==0:initial_foundation_points=[p.copy() for p in fpoints]
    for i,point in enumerate(fpoints):
        near,normal,_,gap=seat_body.find_nearest(point)
        if not inside_surface(seat_body,point) and gap>=.002:continue
        candidates=[near+normal.normalized()*.003,near-normal.normalized()*.003]
        outside=[p for p in candidates if not inside_surface(seat_body,p)]
        if not outside:
            for x in (-1,0,1):
                for y in (-1,0,1):
                    for z in (-1,0,1):
                        if not (x or y or z):continue
                        direction=Vector((x,y,z)).normalized()
                        for distance in tuple(d for d in (.004,.008,.012,.016,.019,.025,.03,.034,.04,.05,.059) if d<foundation_limit):
                            target=point+direction*distance
                            if not inside_surface(seat_body,target):outside.append(target);break
        if not outside:
            exits=[]
            for x in (-1,0,1):
                for y in (-1,0,1):
                    for z in (-1,0,1):
                        if not (x or y or z):continue
                        direction=Vector((x,y,z)).normalized()
                        for distance in (.025,.03,.04,.05,.06,.08):
                            trial=point+direction*distance
                            if not inside_surface(seat_body,trial):exits.append((distance,tuple(direction)));break
            raise RuntimeError('No verified foundation exit within %.1fmm: iteration=%s vertex=%s point=%s nearest=%s gap_mm=%.3f diagnostic_exit=%s' % (foundation_limit*1000,iteration,i,tuple(point),tuple(near),gap*1000,min(exits,default=None)))
        destination=min(outside,key=lambda p:(p-point).length)
        shift=destination-point
        if shift.length>foundation_limit:raise RuntimeError('Foundation local correction exceeded configured bound')
        blend=Matrix.Identity(4)*0;total=0.0
        for group in foundation_obj.data.vertices[i].groups:
            if group.group in bone_transforms:blend+=bone_transforms[group.group]*group.weight;total+=group.weight
        transform=(rig.matrix_world@(blend*(1.0/total) if total else Matrix.Identity(4))@rig.matrix_world.inverted()@foundation_obj.matrix_world).to_3x3()
        foundation_key.data[i].co+=transform.inverted_safe()@shift
    foundation_obj.data.update()
    foundation_obj.update_tag(refresh={'DATA'})
    bpy.context.view_layer.update()
foundation_fit=max((foundation_key.data[i].co-foundation_basis.data[i].co).length for i in range(len(foundation_basis.data)))
print('OCCUPATION_FOUNDATION_CORRECTION_MM',foundation_fit*1000,flush=True)
bpy.context.view_layer.update();check_obj=foundation_obj.evaluated_get(bpy.context.evaluated_depsgraph_get());check_mesh=check_obj.to_mesh()
foundation_pose_fit=max((check_obj.matrix_world@v.co-initial_foundation_points[i]).length for i,v in enumerate(check_mesh.vertices));check_obj.to_mesh_clear()
print('OCCUPATION_FOUNDATION_POSED_CORRECTION_MM',foundation_pose_fit*1000,flush=True)
# The corrective is active only in this pose. Blended joint transforms compress
# vectors, so report bind-key and evaluated motion separately; bound both.
if foundation_pose_fit>foundation_limit or foundation_fit>(.10 if args.visual_probe else .04):
    raise RuntimeError('Foundation correction exceeds posed/bind safety bounds; study rejected')
bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
inner= bpy.data.objects['Street opaque foundation'].evaluated_get(deps)
inner_mesh=inner.to_mesh();inner_mesh.calc_loop_triangles()
seat_foundation=BVHTree.FromPolygons([inner.matrix_world @ v.co for v in inner_mesh.vertices],
                                     [tuple(t.vertices) for t in inner_mesh.loop_triangles],all_triangles=True)
fit_key(rig,obj,seat_body,seated_key,reset_key=False,foundation=seat_foundation,minimum_clearance_m=.002,jacobi=True)
# Re-evaluate the actual corrected mesh before a finishing pass. The
# independent reopened-file audit remains authoritative for sampled clearance.
obj.data.update();obj.update_tag(refresh={'DATA'});bpy.context.view_layer.update()
fit_key(rig,obj,seat_body,seated_key,reset_key=False,foundation=seat_foundation,minimum_clearance_m=.003,jacobi=True)
inner.to_mesh_clear()
skin.to_mesh_clear()
seat_fit=max((seated_key.data[i].co-before_seat[i]).length for i in range(len(before_seat)))
largest=sorted(range(len(before_seat)),key=lambda i:(seated_key.data[i].co-before_seat[i]).length,reverse=True)[:8]
print('OCCUPATION_FIT_VERTICES',[(i,tuple(round(v,4) for v in before_seat[i]),round((seated_key.data[i].co-before_seat[i]).length*1000,3),weights[i]) for i in largest],flush=True)
limit=.10 if args.visual_probe else .05
if seat_fit>limit: raise RuntimeError('Seated correction %.3fmm exceeded %.0fmm; study rejected' % (seat_fit*1000,limit*1000))
for bone in rig.pose.bones: bone.matrix_basis=Matrix.Identity(4)
seated_key.value=0.0
foundation_key.value=0.0
rig.data.pose_position='REST';bpy.context.view_layer.update()
# Separate walking correction, preserving the idle pattern and seated key.
walk_key=obj.shape_key_add(name='Study walk correction');walk_key.value=1.0
rig.data.pose_position='POSE'
for side,sign in [('l',1),('r',-1)]:
    for name,angle in [('thigh_'+side,.30*sign),('upperarm_'+side,.25*sign)]:
        bone=rig.pose.bones.get(name)
        if bone:
            axis=bone.bone.matrix_local.to_3x3().inverted()@Vector((1,0,0))
            bone.rotation_mode='QUATERNION';bone.rotation_quaternion=Quaternion(axis.normalized(),angle)
bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
skin=body.evaluated_get(deps);skinmesh=skin.to_mesh();skinmesh.calc_loop_triangles()
walk_body=VolumeSurface.FromPolygons([skin.matrix_world@v.co for v in skinmesh.vertices],[tuple(t.vertices) for t in skinmesh.loop_triangles],all_triangles=True,strict=True)
inner=foundation_obj.evaluated_get(deps);inner_mesh=inner.to_mesh();inner_mesh.calc_loop_triangles()
walk_foundation=BVHTree.FromPolygons([inner.matrix_world@v.co for v in inner_mesh.vertices],[tuple(t.vertices) for t in inner_mesh.loop_triangles],all_triangles=True)
for finishing_pass in range(2):
    fit_key(rig,obj,walk_body,walk_key,reset_key=False,foundation=walk_foundation,minimum_clearance_m=.003,jacobi=True)
    obj.data.update();obj.update_tag(refresh={'DATA'});bpy.context.view_layer.update()
walk_fit=max((walk_key.data[i].co-basis.data[i].co).length for i in range(len(basis.data)))
print('OCCUPATION_WALK_CORRECTION_MM',walk_fit*1000,flush=True)
if walk_fit>limit:raise RuntimeError('Walk correction exceeded configured limit')
skin.to_mesh_clear();inner.to_mesh_clear();walk_key.value=0.0
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
rig.data.pose_position='REST';bpy.context.view_layer.update()
obj['status']='UNAPPROVED: correspondence study; no skin, layer, motion or visual validation'
obj['source_asset']='MPFB male_casualsuit02, CC0'
obj['max_nearest_body_shift_m']=max_delta
# Source garments are retained in the study; hide only the upper/lower to view it.
for name in ('Activity cotton shirt','Activity cotton trousers'):
    old=bpy.data.objects.get(name)
    if old: old.hide_render=True;old.hide_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(out))
print('OCCUPATION_STUDY',len(vertices),len(cloth_faces),'max_body_shift_m',max_delta,'max_fit_m',max_fit,'seat_fit_m',seat_fit,'unweighted',sum(not x for x in weights),'output',out,flush=True)
