"""Repair transitional cloth constraints without replacing the MPFB physique.

Pass --intervals followed by JSON mapping garment names to lower key indices.
Each repaired midpoint displacement is applied to both contributing endpoints;
quarter points and endpoint poses are then checked in both traversal directions.
The source is saved only after the complete refinement succeeds.
"""
import bpy,sys,json,runpy
from pathlib import Path
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from purpose_seat_topology import native_triangles
from purpose_seat_contact_repair import repair_key
from purpose_cloth_volume import VolumeSurface

source=ROOT/'WorkingAssets/NPCs/record_clerk/desk_study/record_clerk_seat.blend'
requested=json.loads(sys.argv[sys.argv.index('--intervals')+1])
bpy.ops.wm.open_mainfile(filepath=str(source))
rig=bpy.data.objects['record_clerk_rig'];body=bpy.data.objects['record_clerk_MakeHuman_body']
rig.animation_data.action=bpy.data.actions['seat_entry'];rig.data.pose_position='POSE'
cloth=[bpy.data.objects[name] for name in requested]
for obj in bpy.data.objects:
 if obj.type=='MESH' and obj.data.shape_keys:
  for key in obj.data.shape_keys.key_blocks:
   if key.name.startswith(('Seat cloth ','Walk cloth ')):key.value=0
topology=native_triangles(rig,[body]+cloth,ROOT/'characters/npcs/review/record_clerk_seat.glb')
for obj in cloth:
 # Include neighboring segments so a corrected endpoint cannot silently regress
 # the immediately adjacent transition.
 intervals=sorted({max(0,min(119,int(i)+offset)) for i in requested[obj.name] for offset in [-1,0,1]})
 temporary=obj.shape_key_add(name='Temporary interpolation fitting surface',from_mix=False)
 try:
  for sweep in range(3):
   ordered=intervals if sweep%2==0 else list(reversed(intervals))
   for index in ordered:
    left=obj.data.shape_keys.key_blocks['Seat cloth %02d'%index]
    right=obj.data.shape_keys.key_blocks['Seat cloth %02d'%(index+1)]
    for fraction in [.5,.25,.75,0.0,1.0]:
     frame=1+(index+fraction)*.5
     bpy.context.scene.frame_set(int(frame),subframe=frame%1)
     before=[a.co.lerp(b.co,fraction) for a,b in zip(left.data,right.data)]
     for vertex,point in zip(temporary.data,before):vertex.co=point
     temporary.value=1;bpy.context.view_layer.update()
     ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
     tree=VolumeSurface.FromPolygons([ev.matrix_world@v.co for v in mesh.vertices],topology[body.name],all_triangles=True,strict=False);ev.to_mesh_clear()
     hits=repair_key(rig,obj,tree,temporary,topology[obj.name],strict=True)
     temporary.value=0
     if hits:
      for a,b,vertex,point in zip(left.data,right.data,temporary.data,before):
       shift=vertex.co-point;a.co+=shift;b.co+=shift
      print('SEAT_INTERPOLATION_REPAIR',obj.name,sweep,index,fraction,hits,flush=True)
   print('SEAT_INTERPOLATION_SWEEP',obj.name,sweep,flush=True)
 finally:obj.shape_key_remove(temporary)
bpy.context.scene.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(source))
sys.argv.append('--export-only')
runpy.run_path(str(ROOT/'tools/characters/refit_clerk_seat_layers.py'),run_name='__main__')
