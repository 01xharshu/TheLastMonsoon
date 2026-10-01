"""Build and apply a reversible, reference-calibrated Arjun facial shape key.

Calibration runs in Blender on the preserved pre-fit source. The measurements
come from measure_arjun_reference_face.py. The build imports apply_reference_fit before
adding the rig and fitted face assets so those assets follow the shaped body.
"""
import bpy
import hashlib
import json
from pathlib import Path
import numpy as np
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'WorkingAssets/Arjun/reference_fit'
FIT=OUT/'reference_face_fit.json'

def shaped_coordinates(body):
    keys=body.data.shape_keys.key_blocks
    base=np.empty(len(body.data.vertices)*3,dtype=np.float64)
    keys[0].data.foreach_get('co',base)
    shaped=base.reshape(-1,3).copy()
    for key in list(keys)[1:]:
        if abs(key.value)<1e-8 or key.mute:
            continue
        target=np.empty_like(base);relative=np.empty_like(base)
        key.data.foreach_get('co',target)
        key.relative_key.data.foreach_get('co',relative)
        shaped+=(target-relative).reshape(-1,3)*key.value
    return shaped

def gaussian(a,b,width):
    return np.exp(-np.sum((a[:,None,:]-b[None,:,:])**2,axis=2)/(2*width**2))

def apply_reference_fit(body):
    if not FIT.is_file():
        return None
    data=json.loads(FIT.read_text())
    points=shaped_coordinates(body)
    centers=np.array([c['source_local'] for c in data['controls']],dtype=float)
    deltas=np.array([c['delta_local'] for c in data['controls']],dtype=float)
    width=data['kernel_width_m']
    weights=np.linalg.solve(gaussian(centers,centers,width)+
        np.eye(len(centers))*data['regularization'],deltas)
    deformation=gaussian(points,centers,width)@weights*data['strength']
    # Fade smoothly into the neck, scalp and rear skull. The torso and bust
    # cannot be changed by this localized key.
    eye_z=data['eye_z_local']
    smooth=lambda v: np.clip(v,0,1)**2*(3-2*np.clip(v,0,1))
    neck=smooth((points[:,2]-(eye_z-.23))/.08)
    scalp=smooth(((eye_z+.23)-points[:,2])/.07)
    rear=smooth((.09-points[:,1])/.10)
    envelope=neck*scalp*rear
    deformation*=envelope[:,None]
    lengths=np.linalg.norm(deformation,axis=1)
    deformation*=np.minimum(1,data['maximum_displacement_m']/np.maximum(lengths,1e-9))[:,None]
    key=body.shape_key_add(name='Arjun_multiview_face_fit')
    basis=np.array([p.co[:] for p in body.data.shape_keys.key_blocks[0].data])
    key.data.foreach_set('co',(basis+deformation).ravel())
    key.value=1
    body['reference_fit_sha256']=hashlib.sha256(FIT.read_bytes()).hexdigest()
    return {'shape_key':key.name,'control_count':len(centers),
            'maximum_displacement_m':float(np.max(np.linalg.norm(deformation,axis=1))),
            'reference':data['reference'],'reference_sha256':data['reference_sha256'],
            'calibration':str(FIT.relative_to(ROOT))}

def calibrate(measurements="face_landmarks.json"):
    data=json.loads((OUT/measurements).read_text())
    body=bpy.data.objects['Arjun_MakeHuman_Body']
    points=shaped_coordinates(body)
    bpy.context.view_layer.update()
    deps=bpy.context.evaluated_depsgraph_get()
    eyes=bpy.data.objects['Arjun_Eyes']
    eye_points=[eyes.matrix_world@v.co for v in eyes.evaluated_get(deps).data.vertices]
    eye_z=(min(v.z for v in eye_points)+max(v.z for v in eye_points))/2
    camera=bpy.context.scene.camera
    camera.data.type='ORTHO';camera.data.ortho_scale=.38
    camera.location=(0,-2,1.592)
    camera.rotation_euler=(Vector((0,0,1.567))-camera.location).to_track_quat('-Z','Y').to_euler()
    bpy.context.view_layer.update()
    inv=camera.matrix_world.inverted()
    body_matrix=body.matrix_world
    world=np.array([(body_matrix@Vector(p))[:] for p in points])
    cam=np.array([(inv@Vector(p))[:] for p in world])
    pixels=np.stack([(cam[:,0]/.38+.5)*900,(.5-cam[:,1]/.38)*900],axis=1)
    group=body.vertex_groups.get('body')
    actual=np.array([any(g.group==group.index for g in v.groups) for v in body.data.vertices])
    available=np.flatnonzero(actual&(world[:,2]>eye_z-.21)&
        (world[:,2]<eye_z+.18)&(np.abs(world[:,0])<.16)&(world[:,1]<-.025))
    source=np.array(data['render_pixels'])[:,:2]
    reference=np.array(data['reference_normalized'])
    pairs=[(234,454),(93,323),(132,361),(172,397),(149,378),(176,400),
           (33,263),(133,362),(159,386),(145,374),(160,385),(144,373),
           (70,300),(63,293),(105,334),(66,296),(107,336),
           (98,327),(61,291),(37,267),(84,314)]
    for a,b in pairs:
        half=(abs(reference[a,0])+abs(reference[b,0]))/2
        y=(reference[a,1]+reference[b,1])/2
        reference[a]=[np.sign(reference[a,0])*half,y]
        reference[b]=[np.sign(reference[b,0])*half,y]
    for i in [10,152,1,4,5,6,168,195,197,0,17,13,14]: reference[i,0]=0
    center=(source[468]+source[473])/2
    distance=np.linalg.norm(source[473]-source[468])
    axis=(source[473]-source[468])/distance
    if axis[0]<0: axis=-axis
    down=np.array([-axis[1],axis[0]])
    desired=center+reference[:,0,None]*axis*distance+reference[:,1,None]*down*distance
    right=camera.matrix_world.to_3x3()@Vector((1,0,0))
    up=camera.matrix_world.to_3x3()@Vector((0,1,0))
    local=body_matrix.to_3x3().inverted()
    controls=[]
    for index in data['control_indices']:
        # Skip inner lip-gap points; they can hit the mouth's interior rather
        # than the skin and are less reliable than the outer lip outline.
        if index in (13,14): continue
        distances=np.linalg.norm(pixels[available]-source[index],axis=1)
        near=available[np.argsort(distances)[:8]]
        best=near[np.argmin(distances[np.argsort(distances)[:8]]+
            np.maximum(world[near,1]+.10,0)*900)]
        shift=desired[index]-source[index]
        delta=local@(right*(shift[0]/900*.38)-up*(shift[1]/900*.38))
        controls.append({'landmark':index,'vertex':int(best),
            'source_local':points[best].tolist(),'delta_local':list(delta)})
    # Fixed boundaries avoid moving the neck and ears to accommodate the face.
    for x,y,z in [(0,-.05,eye_z-.24),(0,-.03,eye_z+.24),
        (-.14,0,eye_z),(.14,0,eye_z),(0,.12,eye_z),
        (-.10,.08,eye_z+.13),(.10,.08,eye_z+.13)]:
        controls.append({'landmark':None,'vertex':None,
            'source_local':[x,y,z],'delta_local':[0,0,0]})
    result={'reference':data['reference'],'reference_sha256':data['reference_sha256'],
        'reference_crop':data['reference_crop'],
        'baseline_source':str(Path(bpy.data.filepath).relative_to(ROOT)),
        'baseline_sha256':hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest(),
        'method':'Symmetric frontal landmark fit; smooth local Gaussian shape key',
        'eye_z_local':eye_z,'controls':controls,'kernel_width_m':.028,
        'regularization':.008,'strength':.85,'maximum_displacement_m':.020}
    FIT.write_text(json.dumps(result,indent=2)+'\n')
    print('ARJUN_REFERENCE_CALIBRATION',len(controls),'controls')

if __name__=='__main__': calibrate()
