"""Consolidate an MPFB fabric seam and paint a continuous inseam transition.

This edits the garment only; the authoritative human and foundation are not
modified. Preserves all garment shape keys and uses the existing body rig.
"""
import bpy

def prepare_trouser_seams(rig,cloth):
 bpy.ops.object.select_all(action='DESELECT');cloth.select_set(True);bpy.context.view_layer.objects.active=cloth
 for key in cloth.data.shape_keys.key_blocks:key.value=0
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.remove_doubles(threshold=.006);bpy.ops.object.mode_set(mode='OBJECT')
 basis=cloth.data.shape_keys.key_blocks['Basis']
 for vertex in cloth.data.vertices:
  point=basis.data[vertex.index].co
  lateral=max(0.0,min(1.0,(.12-abs(point.x))/.09))
  vertical=max(0.0,min(1.0,(point.z-.65)/.08))*max(0.0,min(1.0,(.95-point.z)/.05))
  factor=lateral*lateral*(3-2*lateral)*vertical
  weights={cloth.vertex_groups[g.group].name:g.weight for g in vertex.groups if rig.pose.bones.get(cloth.vertex_groups[g.group].name)}
  total=sum(weights.values())
  for name,value in weights.items():cloth.vertex_groups[name].add([vertex.index],value/max(total,1e-8)*(1-factor),'REPLACE')
  pelvis=cloth.vertex_groups.get('pelvis') or cloth.vertex_groups.new(name='pelvis')
  pelvis.add([vertex.index],weights.get('pelvis',0)/max(total,1e-8)*(1-factor)+factor,'REPLACE')
 cloth.data.update()
 print('CLERK_PREPARED_FABRIC_SEAM',len(cloth.data.vertices),flush=True)
