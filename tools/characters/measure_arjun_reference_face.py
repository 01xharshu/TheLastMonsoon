"""Measure the supplied frontal portrait and a Leela review render locally.

Requires MediaPipe, NumPy and Pillow. Pass --model to a local FaceLandmarker
task file. The reference is cropped only in memory for measurement.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
import mediapipe as mp

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'WorkingAssets/Arjun/reference_fit'
REF=ROOT/'WorkingAssets/Arjun/references/arjun_core_multiview.png'
parser=argparse.ArgumentParser()
parser.add_argument('--model',required=True)
parser.add_argument('--render',default=str(OUT/'face_baseline.png'))
parser.add_argument('--output',default=str(OUT/'face_landmarks.json'))
parser.add_argument('--profile',action='store_true')
args=parser.parse_args()

options=mp.tasks.vision.FaceLandmarkerOptions(
    base_options=mp.tasks.BaseOptions(model_asset_path=args.model,
        delegate=mp.tasks.BaseOptions.Delegate.CPU),num_faces=1,
    min_face_detection_confidence=.4,min_face_presence_confidence=.4)
def detect(detector,image):
    array=np.array(image.convert('RGB'),dtype=np.uint8)
    result=detector.detect(mp.Image(image_format=mp.ImageFormat.SRGB,data=array))
    if len(result.face_landmarks)!=1:
        raise RuntimeError('Expected one detected face')
    return np.array([[p.x*image.width,p.y*image.height,p.z*image.width]
                     for p in result.face_landmarks[0]])

def normalized(points):
    if args.profile:
        center=points[168,:2]
        vector=points[152,:2]-center
        distance=np.linalg.norm(vector)
        down=vector/distance
        right=np.array([down[1],-down[0]])
        return (points[:,:2]-center)@np.stack([right,down]).T/distance
    # Iris centers remove differences in image scale and small portrait roll.
    left,right=points[468,:2],points[473,:2]
    center=(left+right)/2
    axis=(right-left)/np.linalg.norm(right-left)
    if axis[0]<0: axis=-axis
    down=np.array([-axis[1],axis[0]])
    matrix=np.stack([axis,down])
    return (points[:,:2]-center)@matrix.T/np.linalg.norm(right-left)

with mp.tasks.vision.FaceLandmarker.create_from_options(options) as detector:
    crop=(455,30,610,205) if args.profile else (125,25,280,215)
    image=Image.open(REF).crop(crop)
    if args.profile: image=image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    reference=detect(detector,image)
    rendered=detect(detector,Image.open(args.render))
ref_normalized=normalized(reference)
render_normalized=normalized(rendered)
indices=[10,152,234,454,93,323,132,361,172,397,149,378,176,400,
         33,133,263,362,159,145,386,374,160,144,385,373,
         70,63,105,66,107,300,293,334,296,336,
         1,4,5,6,98,327,168,195,197,
         61,291,0,17,37,267,84,314,13,14]
if args.profile: indices=[10,168,6,197,195,5,4,1,2,0,17,152,199,200]
delta=ref_normalized[indices]-render_normalized[indices]
data={
    'reference':str(REF.relative_to(ROOT)),
    'reference_sha256':hashlib.sha256(REF.read_bytes()).hexdigest(),
    'reference_crop':list(crop),
    'render':str(Path(args.render).resolve().relative_to(ROOT)),
    'render_sha256':hashlib.sha256(Path(args.render).read_bytes()).hexdigest(),
    'method':'MediaPipe FaceLandmarker; profile glabella-chin alignment' if args.profile else
        'MediaPipe FaceLandmarker; iris-distance scale and roll alignment',
    'profile':args.profile,
    'reference_pixels':reference.tolist(),'render_pixels':rendered.tolist(),
    'reference_normalized':ref_normalized.tolist(),
    'render_normalized':render_normalized.tolist(),
    'control_indices':indices,
    'landmark_rms_in_iris_distances':float(np.sqrt(np.mean(np.sum(delta**2,axis=1)))),
}
Path(args.output).write_text(json.dumps(data,indent=2)+'\n')
for name,pair in [('face_width',(234,454)),('eye_width',(33,133)),
                  ('nose_width',(98,327)),('mouth_width',(61,291))]:
    print(name,'reference',round(float(np.linalg.norm(ref_normalized[pair[0]]-ref_normalized[pair[1]])),3),
          'model',round(float(np.linalg.norm(render_normalized[pair[0]]-render_normalized[pair[1]])),3))
print('REFERENCE_LANDMARKS',data['landmark_rms_in_iris_distances'])
