"""Recoverable trouser fold revision; preserve source physique and rig."""
from pathlib import Path
import bpy, math, json, hashlib
root=Path(__file__).resolve().parents[2]
source=root/'WorkingAssets/Arjun/candidate/arjun_animated_candidate.blend'
out=root/'WorkingAssets/Arjun/riding_cloth'
out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(source))
rig=bpy.data.objects['Arjun_Rig']
rig.data.pose_position='REST'
rig.animation_data_clear()
cloth=[]
for side in [-1,1]:
    obj=bpy.data.objects['Arjun_DrapedTrousers_'+str(side)]
    # Author broad longitudinal gathers with low-amplitude diagonal breaks.
    # Original rings use 13/21 corrugations, giving a sharp repeating pattern.
    for j in range(39):
        t=j/38;z=.205+t*.765
        cx=side*(.196-.07*t);cy=-.005-.018*math.sin(t*math.pi)
        envelope=math.sin(math.pi*t)**1.2
        radius=.052+.053*math.sin(math.pi*t)**1.2
        for i in range(96):
            a=2*math.pi*i/96
            fold=(.0045*math.sin(4*a-t*3+side*.7)+.0018*math.sin(7*a+t*4))*envelope
            obj.data.vertices[j*96+i].co=(cx+(radius+fold)*math.cos(a),cy+(radius*1.02+fold)*math.sin(a),z+.0006*math.sin(3*a+side*.7)*envelope)
    obj['construction']='Broader cotton gathers, restrained diagonal breaks; source thickness/skin preserved'
    cloth.append(obj)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'arjun_riding_cloth.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in [rig]+cloth:
    obj.hide_set(False);obj.select_set(True)
bpy.context.view_layer.objects.active=rig
asset=root/'characters/arjun/arjun_riding_cloth.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_animations=False,export_yup=True)
(out/'manifest.json').write_text(json.dumps({'source':str(source.relative_to(root)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'output':str(asset.relative_to(root)),'output_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'body_changed':False,'rig_changed':False,'final_cloth_approved':False},indent=2)+'\n')
print('RIDING CLOTH SOURCE EXPORT PASS')
