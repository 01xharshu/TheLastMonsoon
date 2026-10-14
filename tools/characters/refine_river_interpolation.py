"""Fit source endpoint corrections against actual native intermediate poses.

The input is disposable native geometry. The complete MPFB body is unchanged.
Every intermediate correction moves all contributing source keys by the same
bind-space displacement, so their weighted mixture receives that displacement.
"""
import bpy,json,sys
from pathlib import Path
from mathutils import Matrix,Vector
from mathutils.kdtree import KDTree
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from river_cloth_correctives import apply_river_pose
from river_coherent_cloth import fit_key
from purpose_cloth_volume import VolumeSurface
from mathutils.bvhtree import BVHTree
from river_asset_export import export_river_asset,asset_digest
from datetime import datetime
from zoneinfo import ZoneInfo
folder=Path(sys.argv[sys.argv.index('--')+1])
records=[json.loads(path.read_text()) for path in sorted(folder.glob('river_*.json'))]
if not records:raise RuntimeError('Native intermediate poses required')
if '--diagnose-foundation' in sys.argv and any(flag in sys.argv for flag in ['--fair-upper','--fair-posed-upper','--sew-upper','--remesh-chest','--subdivide-upper','--subdivide-foundation']):
 raise RuntimeError('Read-only foundation diagnostics cannot include construction operations')
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/river_woman/river_woman_motion.blend'))
bpy.context.preferences.filepaths.save_version=0
rig=bpy.data.objects['village_woman_rig'];body=bpy.data.objects['village_woman_MakeHuman_body']
from river_body_physique import restore_donor_physique
restore_donor_physique(ROOT,body)
data=json.loads((ROOT/'WorkingAssets/NPCs/river_woman/poses.json').read_text())
c=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)));inv=c.inverted()
corrections={name:(c@Matrix(rest)@inv).inverted()@rig.data.bones[name].matrix_local for name,rest in data['rest'].items() if name in rig.data.bones}
rig.animation_data_clear();rig.data.pose_position='POSE'
objects={name:bpy.data.objects[name] for name in ['Fitted cotton upper base','Wrapped sari lower drape','Sari lower border','Woven sari pallu over blouse','Opaque fitted bra and thong foundation']}
if '--fit-foundation-envelope' in sys.argv and 'Retained seam-fitted river upper' not in bpy.data.objects:
 reference=objects['Fitted cotton upper base'].copy()
 reference.data=objects['Fitted cotton upper base'].data.copy()
 reference.name='Retained seam-fitted river upper';reference['river_source_only']=True
 bpy.context.collection.objects.link(reference);reference.hide_render=True;reference.hide_set(True)
if objects['Fitted cotton upper base'].get('river_composite',False):objects['Woven sari pallu over blouse']=objects['Fitted cotton upper base']
if '--subdivide-foundation' in sys.argv:
 from river_chest_construction import remesh_chest
 from river_surface_binding import bind_surface
 foundation_obj=objects['Opaque fitted bra and thong foundation']
 rig.data.pose_position='REST'
 for key in foundation_obj.data.shape_keys.key_blocks:key.value=0
 remesh_chest(foundation_obj,subdivide_only=True,foundation=True)
 masks=[(modifier,modifier.show_viewport) for modifier in body.modifiers if modifier.type=='MASK']
 for modifier,_ in masks:modifier.show_viewport=False
 bpy.context.view_layer.update();ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
 try:
  if len(mesh.vertices)!=len(body.data.vertices):raise RuntimeError('Foundation binding body indexing changed')
  group=body.vertex_groups['body'].index
  human={vertex.index for vertex in body.data.vertices if any(weight.group==group and weight.weight>.5 for weight in vertex.groups)}
  bind_surface(foundation_obj,body,mesh,human)
  bindings=json.loads(foundation_obj['river_surface_bindings'])
  for binding in bindings:binding[-1]=.010
  foundation_obj['river_surface_bindings']=json.dumps(bindings)
 finally:
  ev.to_mesh_clear()
  for modifier,enabled in masks:modifier.show_viewport=enabled
 rig.data.pose_position='POSE'
if '--remesh-chest' in sys.argv or '--subdivide-upper' in sys.argv:
 from river_chest_construction import remesh_chest
 remesh_chest(objects['Fitted cotton upper base'],subdivide_only='--subdivide-upper' in sys.argv)
if '--fair-upper' in sys.argv or '--fair-posed-upper' in sys.argv or '--sew-upper' in sys.argv:
 from river_cloth_fairing import fair_upper
 sewn='--sew-upper' in sys.argv
 fair_upper(objects['Fitted cotton upper base'],rounds=0 if sewn else 6,posed=(rig,data,c,corrections) if '--fair-posed-upper' in sys.argv or sewn else None,sew=sewn)
for obj in objects.values():
 if obj.data.shape_keys is None:continue
 for key in obj.data.shape_keys.key_blocks:key.value=0
# Validate the coordinate conversion before changing any retained source.
first=records[0];apply_river_pose(rig,first['bones'],c,corrections)
transform=rig.matrix_world@c@Matrix(first['skeleton_transform']).inverted()
points=[transform@Vector(point) for entry in first['body'] for point in entry['vertices']]
kd=KDTree(len(points))
for index,point in enumerate(points):kd.insert(point,index)
kd.balance();ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
error=max(kd.find(ev.matrix_world@vertex.co)[2] for vertex in mesh.vertices);ev.to_mesh_clear()
print('RIVER_NATIVE_ALIGNMENT_M',error,flush=True)
if error>.0001:raise RuntimeError('Source/native pose spaces do not agree')
if '--align-only' in sys.argv:raise SystemExit(0)
if '--cloth-align-only' in sys.argv:
 for record in records:
  apply_river_pose(rig,record['bones'],c,corrections)
  transform=rig.matrix_world@c@Matrix(record['skeleton_transform']).inverted()
  for entry in record['garments']:
   obj=objects[entry['name']]
   if obj.data.shape_keys is None:continue
   for key in obj.data.shape_keys.key_blocks:key.value=0
   for name,weight in entry['active_keys']:obj.data.shape_keys.key_blocks[name].value=weight
   bpy.context.view_layer.update()
   native=[transform@Vector(point) for point in entry['vertices']]
   kd=KDTree(len(native))
   for index,point in enumerate(native):kd.insert(point,index)
   kd.balance();ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
   gap=max(kd.find(ev.matrix_world@vertex.co)[2] for vertex in mesh.vertices)
   if '--foundation-outliers' in sys.argv and entry['name']=='Opaque fitted bra and thong foundation':
    body_points=[];body_faces=[]
    for part in record['body']:
     offset=len(body_points);body_points.extend(transform@Vector(point) for point in part['vertices'])
     ids=part['indices'];body_faces.extend(tuple(offset+i for i in ids[j:j+3]) for j in range(0,len(ids),3))
    skin=BVHTree.FromPolygons(body_points,body_faces,all_triangles=True)
    measured=sorted(((skin.find_nearest(ev.matrix_world@vertex.co)[3],vertex.index) for vertex in mesh.vertices),reverse=True)
    basis=obj.data.shape_keys.key_blocks['Basis']
    for distance,index in measured[:3]:
     weights=sorted(((assignment.weight,obj.vertex_groups[assignment.group].name) for assignment in obj.data.vertices[index].groups),reverse=True)[:3]
     print('RIVER_FOUNDATION_OUTLIER',record['label'],'vertex',index,'gap_m',distance,'rest',tuple(round(v,5) for v in basis.data[index].co),'skin_weights',weights,flush=True)
   ev.to_mesh_clear()
   print('RIVER_NATIVE_CLOTH_ALIGNMENT',record['sample'],entry['name'],gap,flush=True)
 raise SystemExit(0)
checkpoint=ROOT/'WorkingAssets/NPCs/river_woman/fit_checkpoint.json'
prior_checkpoint=json.loads(checkpoint.read_text()) if checkpoint.exists() else {}
operations=[flag for flag in ['--fair-upper','--fair-posed-upper','--sew-upper','--remesh-chest','--subdivide-upper','--subdivide-foundation'] if flag in sys.argv] or prior_checkpoint.get('operations',[])
diagnostic='--diagnose-foundation' in sys.argv
if diagnostic and '--canonical-foundation' not in sys.argv:
 raise RuntimeError('Foundation diagnostic requires canonical reattachment')
def report_foundation(stage,obj):
 bpy.context.view_layer.update()
 evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
 try:
  measured=[(tree.find_nearest(evaluated.matrix_world@vertex.co)[3],vertex.index) for vertex in mesh.vertices]
  distances=sorted(distance for distance,_ in measured)
  print('RIVER_FOUNDATION_STAGE',record['label'],stage,'median_m',distances[len(distances)//2],'maximum_m',max(distances),flush=True)
  if stage=='body_fitted':
   basis=obj.data.shape_keys.key_blocks['Basis']
   for distance,index in sorted(measured,reverse=True)[:3]:
    rest=tuple(round(v,5) for v in basis.data[index].co)
    posed=tuple(round(v,5) for v in evaluated.matrix_world@mesh.vertices[index].co)
    print('RIVER_FOUNDATION_OUTLIER',record['label'],'vertex',index,'gap_m',distance,'rest',rest,'posed',posed,flush=True)
 finally:evaluated.to_mesh_clear()
def save_fit_checkpoint(completed_sweeps):
 if '--upper-only' not in sys.argv and '--foundation-only' not in sys.argv:return
 for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
 rig.data.pose_position='REST';bpy.context.view_layer.update()
 source=ROOT/'WorkingAssets/NPCs/river_woman/river_woman_motion.blend'
 bpy.ops.wm.save_as_mainfile(filepath=str(source))
 scope='foundation' if '--foundation-only' in sys.argv else 'upper'
 state={'status':'SOURCE_FIT_IN_PROGRESS','updated_ist':datetime.now(ZoneInfo('Asia/Kolkata')).isoformat(),'source':str(source.relative_to(ROOT)),'source_sha256':asset_digest(source),'operations':operations,'completed_sweeps':prior_checkpoint.get('completed_sweeps',0)+completed_sweeps,'fit_foundation_envelope':'--fit-foundation-envelope' in sys.argv,'fit_scope':scope,'canonical_foundation':'--canonical-foundation' in sys.argv,'next_command':'python3 tools/characters/rebuild_river_woman.py --fit-current'+(' --foundation-only --canonical-foundation' if scope=='foundation' else ''),'runtime_pending_export':True}
 temporary=checkpoint.with_suffix('.tmp');temporary.write_text(json.dumps(state,indent=2)+'\n');temporary.replace(checkpoint)
 rig.data.pose_position='POSE'
 print('RIVER_FIT_CHECKPOINT',state['completed_sweeps'],state['source_sha256'],flush=True)
if any(flag in sys.argv for flag in ['--fair-upper','--fair-posed-upper','--sew-upper','--remesh-chest','--subdivide-upper','--subdivide-foundation']):save_fit_checkpoint(0)
for sweep in range(6 if '--foundation-only' in sys.argv or '--finish-upper' in sys.argv else 3):
 changed=0;worst=0.0
 for record in records if sweep%2==0 else reversed(records):
  apply_river_pose(rig,record['bones'],c,corrections)
  if '--canonical-foundation' in sys.argv:
   mask_state=[(modifier,modifier.show_viewport) for modifier in body.modifiers if modifier.type=='MASK']
   for modifier,_ in mask_state:modifier.show_viewport=False
   bpy.context.view_layer.update();ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
   try:
    body_points=[ev.matrix_world@vertex.co for vertex in mesh.vertices]
    body_normals=[(ev.matrix_world.to_3x3()@vertex.normal).normalized() for vertex in mesh.vertices]
   finally:
    ev.to_mesh_clear()
    for modifier,enabled in mask_state:modifier.show_viewport=enabled
    bpy.context.view_layer.update()
  transform=rig.matrix_world@c@Matrix(record['skeleton_transform']).inverted()
  points=[];faces=[]
  for entry in record['body']:
   offset=len(points);points.extend(transform@Vector(point) for point in entry['vertices'])
   ids=entry['indices'];reverse=entry.get('winding_sign',1)<0
   faces.extend(tuple(offset+i for i in (reversed(ids[j:j+3]) if reverse else ids[j:j+3])) for j in range(0,len(ids),3))
  tree=VolumeSurface.FromPolygons(points,faces,all_triangles=True,strict='--finish-upper' in sys.argv)
  foundation=None
  if '--fit-foundation-envelope' in sys.argv:
   entry=next(entry for entry in record['garments'] if entry['name']=='Opaque fitted bra and thong foundation')
   foundation_points=[transform@Vector(point) for point in entry['vertices']]
   ids=entry['indices'];foundation_faces=[tuple(ids[j:j+3]) for j in range(0,len(ids),3)]
   foundation=BVHTree.FromPolygons(foundation_points,foundation_faces,all_triangles=True)
  handled=set()
  for entry in record['garments']:
   if '--upper-only' in sys.argv and entry['name'] not in ['Fitted cotton upper base','Woven sari pallu over blouse']:continue
   if '--foundation-only' in sys.argv and entry['name']!='Opaque fitted bra and thong foundation':continue
   obj=objects[entry['name']]
   if obj.name in handled:continue
   handled.add(obj.name)
   if obj.data.shape_keys is None or not entry['active_keys']:continue
   basis=obj.data.shape_keys.key_blocks['Basis']
   active=[(obj.data.shape_keys.key_blocks[name],weight) for name,weight in entry['active_keys']]
   if abs(sum(weight for _,weight in active)-1.0)>.0001:raise RuntimeError('Unexpected native morph weight sum')
   before=[vertex.co.copy()+sum(((key.data[index].co-vertex.co)*weight for key,weight in active),Vector()) for index,vertex in enumerate(basis.data)]
   temporary=obj.shape_key_add(name='Temporary native interpolation surface',from_mix=False)
   try:
    for vertex,point in zip(temporary.data,before):vertex.co=point
    temporary.value=1
    try:
     if '--canonical-foundation' in sys.argv and entry['name']=='Opaque fitted bra and thong foundation':
      from river_surface_binding import apply_surface
      apply_surface(rig,obj,temporary,body_points,body_normals)
      if diagnostic:report_foundation('attached',obj)
      fit_key(rig,obj,tree,temporary,reset_key=False)
      if diagnostic:report_foundation('body_fitted',obj)
      shift=max((vertex.co-point).length for vertex,point in zip(temporary.data,before))
     elif foundation is not None and entry['name'] in ['Fitted cotton upper base','Woven sari pallu over blouse']:
      from river_foundation_contact import fit_foundation_contacts
      shift=fit_foundation_contacts(rig,obj,tree,temporary,foundation_points,foundation_faces)
     else:shift=fit_key(rig,obj,tree,temporary,reset_key=False)
    except RuntimeError as error:
     raise RuntimeError('Native pose '+str(record['label'])+' garment '+obj.name+': '+str(error)) from error
    temporary.value=0
    if shift>.001 and not diagnostic:
     changed+=1;worst=max(worst,shift)
     for index,(vertex,point) in enumerate(zip(temporary.data,before)):
      delta=vertex.co-point
      if delta.length>.000001:
       for key,_ in active:key.data[index].co+=delta
   finally:obj.shape_key_remove(temporary)
  print('RIVER_INTERPOLATION_POSE',sweep,record['label'],'changed_surfaces',changed,flush=True)
 print('RIVER_INTERPOLATION_SWEEP',sweep,'changed_surfaces',changed,'max_shift_m',worst,flush=True)
 if diagnostic:raise SystemExit(0) # Read-only diagnostic: never save or export.
 save_fit_checkpoint(sweep+1)
 if changed==0:break # Repeating an unchanged sweep cannot improve the same pose constraints.
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
rig.data.pose_position='REST'
export_river_asset(ROOT,rig,body,len(objects['Opaque fitted bra and thong foundation'].data.polygons))
if checkpoint.exists():checkpoint.unlink()
