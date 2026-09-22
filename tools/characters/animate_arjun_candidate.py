"""Author sampled body animation on the isolated MPFB candidate, then render review poses.

The walk uses explicit ankle trajectories and a two-bone solve, not rotating the
entire character. Sitting targets a 0.46 m seat; prone targets a level floor.
These are editable first-pass clips, pending visual/contact acceptance.
"""
import bpy
import json
import math
import hashlib
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'WorkingAssets/Arjun/candidate'
REVIEW=ROOT/'docs/characters/arjun'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'arjun_reference_candidate.blend'))
rig=bpy.data.objects['Arjun_Rig']
scene=bpy.context.scene
scene.render.fps=30
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
heads={b.name:b.head_local.copy() for b in rig.data.bones}
tails={b.name:b.tail_local.copy() for b in rig.data.bones}
hip=heads['pelvis']
saved_modifiers=[]
for obj in scene.objects:
    if obj.type=='MESH':
        for m in obj.modifiers:
            saved_modifiers.append((m,m.show_viewport))
            m.show_viewport=False
rig.animation_data_clear()
rig.animation_data_create()
clips={}
contact_samples=[]

def smooth(t):
    t=max(0,min(1,t));return t*t*(3-2*t)

def reset():
    for b in rig.pose.bones:
        b.rotation_mode='QUATERNION';b.matrix_basis=Matrix.Identity(4)

def update():
    bpy.context.view_layer.update()

def aim(name, start, end, extra_rotation=None):
    """Orient a bone in armature space while retaining its rest roll."""
    direction=(end-start).normalized()
    original=(tails[name]-heads[name]).normalized()
    rotation=original.rotation_difference(direction).to_matrix().to_4x4()
    mat=rotation @ rest[name]
    if extra_rotation is not None:mat=extra_rotation @ mat
    mat.translation=start
    rig.pose.bones[name].matrix=mat
    update()
    return rotation

def limb(upper,lower,end_name,target,pole, foot=False,foot_angle=0):
    origin=rig.pose.bones[upper].head.copy()
    a=(tails[upper]-heads[upper]).length
    b=(tails[lower]-heads[lower]).length
    delta=target-origin
    distance=max(.001,min(delta.length,a+b-.0001))
    direction=delta.normalized()
    plane=pole-direction*pole.dot(direction)
    if plane.length<.001:plane=Vector((1,0,0))
    plane.normalize()
    along=(a*a-b*b+distance*distance)/(2*distance)
    bend=math.sqrt(max(0,a*a-along*along))
    knee=origin+direction*along+plane*bend
    actual=origin+direction*distance
    aim(upper,origin,knee)
    rotation=aim(lower,knee,actual)
    if foot:
        mat=Matrix.Rotation(foot_angle,4,'X') @ rest[end_name]
    else:
        mat=rotation @ rest[end_name]
    mat.translation=actual
    rig.pose.bones[end_name].matrix=mat
    update()
    return actual

def pose(kind,t=0,progress=1):
    reset()
    angle=0.;root_shift=Vector((0,0,0));sitting=0.;prone=0.
    phase=math.tau*t
    if kind=='walk':
        root_shift.z=-.050+.012*math.cos(phase*2)
    elif kind=='sit':
        sitting=smooth(progress)
        root_shift=Vector((0,.025,-.375))*sitting
        angle=.065*math.sin(sitting*math.pi)
    elif kind=='prone':
        prone=smooth(progress)
        root_shift=Vector((0,0,.195-hip.z))*prone
        angle=math.pi*.5*prone
    master=Matrix.Translation(hip+root_shift) @ Matrix.Rotation(angle,4,'X') @ Matrix.Translation(-hip)
    rig.pose.bones['Root'].matrix=master @ rest['Root']
    update()
    # Small breathing/head compensation; the root is the physical posture frame.
    if prone:
        b=rig.pose.bones['neck_01']
        axis=rest['neck_01'].to_3x3().inverted() @ Vector((1,0,0))
        b.rotation_quaternion=Quaternion(axis,-.32*prone)
        update()
    for side,sign in [('l',1),('r',-1)]:
        ankle=heads['foot_'+side].copy()
        pole=Vector((0,-1,0))
        foot_angle=0.
        stance=False
        if kind=='walk':
            cycle=(t+(0 if side=='l' else .5))%1
            ankle.x=sign*.165
            if cycle<.60:
                u=cycle/.60
                ankle.y=-.25+.50*u
                stance=True
            else:
                u=(cycle-.60)/.40
                ankle.y=.25-.50*smooth(u)
                ankle.z+=.09*math.sin(math.pi*u)
                foot_angle=-.12*math.sin(math.pi*u)
        elif sitting:
            ankle=ankle.lerp(Vector((sign*.17,-.40,heads['foot_'+side].z)),sitting)
        elif prone:
            ankle=ankle.lerp(Vector((sign*.17,.79,.115)),prone)
            pole=Vector((0,-math.cos(angle),-math.sin(angle)))
            foot_angle=angle*.9
        actual=limb('thigh_'+side,'calf_'+side,'foot_'+side,ankle,pole,True,foot_angle)
        if kind=='walk':
            contact_samples.append({'phase':round(t,5),'side':side,'stance':stance,
                'target':list(ankle),'actual':list(actual),'target_error_m':(actual-ankle).length})
        hand=Vector((sign*.255,-.055,.875))
        arm_pole=Vector((sign*.7,.45,-.12))
        if kind=='walk':
            hand.y+=sign*.11*math.sin(phase)
            hand.z+=.01*math.cos(phase*2)
        elif sitting:
            hand=hand.lerp(Vector((sign*.17,-.36,.575)),sitting)
            arm_pole=Vector((sign*.8,.2,-.2))
        elif prone:
            hand=hand.lerp(Vector((sign*.21,-.78,.09)),prone)
            arm_pole=Vector((sign*.5,.1,-1))
        wrist=limb('upperarm_'+side,'lowerarm_'+side,'hand_'+side,hand,arm_pole)
        if sitting>.5 or prone>.5:
            aim('hand_'+side,wrist,wrist+Vector((0,-.035,-.003)))
        # Relaxed articulated fingers, not an unweighted mitten.
        for finger in ['index','middle','ring','pinky','thumb']:
            for joint in ['01','02','03']:
                name=f'{finger}_{joint}_{side}'
                if name in rig.pose.bones:
                    rig.pose.bones[name].rotation_quaternion=Quaternion((1,0,0),.07 if prone else .13)
    update()

def make_action(name,frames,sampler,loop=False):
    action=bpy.data.actions.new(name)
    action.use_fake_user=True
    rig.animation_data.action=action
    for frame in range(1,frames+1):
        scene.frame_set(frame)
        sampler((frame-1)/(frames-1))
        for bone in rig.pose.bones:
            bone.keyframe_insert('location',frame=frame,group=bone.name)
            bone.keyframe_insert('rotation_quaternion',frame=frame,group=bone.name)
            bone.keyframe_insert('scale',frame=frame,group=bone.name)
    action['loop']=loop
    action['review_status']='FIRST_PASS_CONTACT_REVIEW_REQUIRED'
    clips[name]={'frames':frames,'fps':30,'duration_s':(frames-1)/30,'loop':loop}
    print('AUTHORED',name,frames,flush=True)
    return action

make_action('idle',61,lambda t:pose('idle'),True)
make_action('walk',37,lambda t:pose('walk',t),True)
make_action('sit_down',46,lambda t:pose('sit',progress=t))
make_action('sit_idle',61,lambda t:pose('sit',t),True)
make_action('stand_up',46,lambda t:pose('sit',progress=1-t))
make_action('prone_down',61,lambda t:pose('prone',progress=t))
make_action('prone_idle',61,lambda t:pose('prone',t),True)
make_action('prone_up',61,lambda t:pose('prone',progress=1-t))
for m,visible in saved_modifiers:m.show_viewport=visible
rig.animation_data.action=bpy.data.actions['idle']
scene.frame_start=1;scene.frame_end=61;scene.frame_set(1)
rig['animation_notes']='Walk speed 0.6944 m/s at 1x; in-place. Sitting requires seat top 0.46 m. Prone assumes flat ground. Pending full contact/deformation approval.'

# Review support is a separate studio prop; it is never part of the character export.
bpy.ops.mesh.primitive_cube_add(size=1,location=(0,.06,.435))
seat=bpy.context.object;seat.name='REVIEW_Seat_46cm';seat.dimensions=(.62,.53,.05)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
mat=bpy.data.materials.new('Review seat wood');mat.diffuse_color=(.12,.067,.032,1);seat.data.materials.append(mat)
seat.hide_render=True;seat.hide_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'arjun_animated_candidate.blend'))
manifest={'status':'FIRST_PASS','clips':clips,'rig_bones':len(rig.data.bones),
          'walk_nominal_speed_m_s':.5/(.6*1.2),'seat_height_m':.46,
          'max_ankle_target_error_m':max(x['target_error_m'] for x in contact_samples),
          'contact_samples':contact_samples,
          'blend_sha256':hashlib.sha256((OUT/'arjun_animated_candidate.blend').read_bytes()).hexdigest(),
          'approval':{'walking_visual':False,'sitting_contact':False,'prone_contact':False,'transitions':False,'runtime':False}}
(REVIEW/'animation_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('ANIMATION_BUILD_SAVED',flush=True)

scene.cycles.samples=16
camera=scene.camera
views=[('idle','front',(0,-4,.9),(0,0,.9),1.98),
       ('idle','side',(4,0,.9),(0,0,.9),1.98),
       ('idle','back',(0,4,.9),(0,0,.9),1.98),
       ('idle','three_quarter',(3,-4,1.1),(0,0,.9),1.98),
       ('walk','walk_contact',(3,-4,1.0),(0,0,.85),1.98),
       ('sit_idle','sitting',(3,-4,1.3),(0,-.15,.60),1.55),
       ('prone_idle','prone',(3,-3,1.9),(0,0,.18),2.25)]
for action,name,position,target,scale in views:
    rig.animation_data.action=bpy.data.actions[action]
    scene.frame_set(1 if action!='walk' else 7)
    seat.hide_render=action!='sit_idle';seat.hide_set(action!='sit_idle')
    camera.location=position;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=scale
    scene.render.filepath=str(REVIEW/('animated_'+name+'.png'))
    bpy.ops.render.render(write_still=True)
    print('REVIEW_RENDER',name,flush=True)
