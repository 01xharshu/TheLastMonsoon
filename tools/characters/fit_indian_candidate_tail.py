"""Refit the isolated woman's sari tail to her actual back and blouse."""
import bpy,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from street_female_garments import body_volume
from whole_body_contract import retain_complete_body
args=sys.argv[sys.argv.index('--')+1:];slug=args[args.index('--identity')+1]
path=Path(args[args.index('--source')+1]).expanduser().resolve() if '--source' in args else ROOT/'WorkingAssets/NPCs/indian_body_candidates'/slug/'candidate.blend'
gap=float(args[args.index('--gap')+1]) if '--gap' in args else .018
if not .004<=gap<=.02:raise ValueError('Tail construction clearance outside4–20mm')
bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.preferences.filepaths.save_version=0
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='REST'
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
for mod in body.modifiers:
 if mod.type=='MASK':mod.show_viewport=False
bpy.context.view_layer.update();skin=body_volume(body)
blouse=bpy.data.objects['Street coherent cotton blouse and pallu'];dg=bpy.context.evaluated_depsgraph_get();ev=blouse.evaluated_get(dg);mesh=ev.to_mesh();mesh.calc_loop_triangles()
cotton=BVHTree.FromPolygons([ev.matrix_world@v.co for v in mesh.vertices],[tuple(t.vertices) for t in mesh.loop_triangles],all_triangles=True);ev.to_mesh_clear()
tail=bpy.data.objects['Street sari back tail'];inverse=tail.matrix_world.inverted();largest=0.;misses=0
blocks=[tail.data.vertices]
if tail.data.shape_keys:blocks += [key.data for key in tail.data.shape_keys.key_blocks]
basis=tail.data.shape_keys.reference_key.data if tail.data.shape_keys else tail.data.vertices
starts=[vertex.co.copy() for vertex in basis]
for index,coordinate in enumerate(starts):
 p=tail.matrix_world@coordinate;origin=Vector((p.x,.7,p.z));hits=[]
 hit=skin.ray_cast(origin,Vector((0,-1,0)))
 if hit[0] is not None:hits.append(hit[0].y)
 if not hits:
  near=skin.find_nearest(Vector((p.x,.16,p.z)))
  if near[0] is None or near[3]>.18:
   print('TAIL_MISS',tuple(p),None if near[0] is None else (tuple(near[0]),near[3]),flush=True);misses+=1;continue
  hits.append(near[0].y)
 # A front-only blouse hit cannot substitute for missing back skin support.
 cloth_hit=cotton.ray_cast(origin,Vector((0,-1,0)))
 if cloth_hit[0] is not None:hits.append(cloth_hit[0].y)
 target=max(hits)+gap
 if abs(target-p.y)>.12:print('TAIL_BOUND_POINT',index,tuple(p),'target_y',target,'surfaces',hits,flush=True)
 largest=max(largest,abs(target-p.y));p.y=target;change=inverse@p-coordinate
 for block in blocks:block[index].co+=change
if largest>.12:print('TAIL_FIT_BOUND',slug,'max_mm',largest*1000,flush=True)
if largest>.12:raise RuntimeError('Tail fit exceeds120mm; candidate not saved')
if misses:raise RuntimeError(f'{misses} tail vertices did not find a back surface')
tail.data.update();tail['candidate_refit']=str(gap*1000)+'mm behind actual body or blouse surface';retain_complete_body(body)
bpy.ops.wm.save_as_mainfile(filepath=str(path));print('INDIAN_TAIL_FIT',slug,'max_shift_mm',largest*1000,flush=True)
