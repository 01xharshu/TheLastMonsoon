"""Verify the full-skin simulation collider follows the delivered body poses."""
import bpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from purpose_seat_topology import native_triangles
source=ROOT/'WorkingAssets/NPCs/record_clerk/desk_study/record_clerk_seat_physics_candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
rig=bpy.data.objects['record_clerk_rig'];body=bpy.data.objects['record_clerk_MakeHuman_body']
rig.animation_data.action=bpy.data.actions['seat_entry']
faces=native_triangles(rig,[body],ROOT/'characters/npcs/review/record_clerk_seat_physics_candidate.glb')[body.name]
rig.data.pose_position='REST';bpy.context.view_layer.update()
ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
data=bpy.data.meshes.new('Temporary collider diagnostic');data.from_pydata([v.co[:] for v in mesh.vertices],[],faces);data.update()
collider=bpy.data.objects.new('Temporary full MPFB collider diagnostic',data);bpy.context.collection.objects.link(collider)
collider.parent=rig;collider.matrix_parent_inverse=body.matrix_parent_inverse.copy();collider.matrix_basis=body.matrix_basis.copy()
for group in body.vertex_groups:collider.vertex_groups.new(name=group.name)
for vertex in mesh.vertices:
 for group in vertex.groups:collider.vertex_groups[group.group].add([vertex.index],group.weight,'REPLACE')
ev.to_mesh_clear()
collider.modifiers.new('Complete skin rig','ARMATURE').object=rig
collider.modifiers.new('Fabric collision','COLLISION')
print('CLERK_COLLIDER_SETTINGS',getattr(collider.collision,'use',None),'body_modifiers',[(m.name,m.type,getattr(m,'use_deform_preserve_volume',None),getattr(m,'vertex_group',None)) for m in body.modifiers],flush=True)
rig.data.pose_position='POSE'
for frame in [1,31,61]:
 bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
 a=body.evaluated_get(dg);b=collider.evaluated_get(dg);ma=a.to_mesh();mb=b.to_mesh()
 assert len(ma.vertices)==len(mb.vertices)
 maximum=max((a.matrix_world@va.co-b.matrix_world@vb.co).length for va,vb in zip(ma.vertices,mb.vertices))
 print('CLERK_COLLIDER_BODY_MAXIMUM_MM',frame,maximum*1000,flush=True)
 a.to_mesh_clear();b.to_mesh_clear()
 if maximum>.001:raise RuntimeError('Collider does not follow the complete source body')
