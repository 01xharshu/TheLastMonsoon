extends RefCounted
## Slow, role-specific observation over the imported idle; body/cloth stays intact.
static func build(source:Animation,role:String,rig:Skeleton3D,rig_path:NodePath) -> Animation:
 var clip:=source.duplicate(true) as Animation
 var original_length:=source.length
 clip.length=original_length*4.0
 for track in source.get_track_count():
  for repeat in range(1,4):
   for key in source.track_get_key_count(track):
    var time:=source.track_get_key_time(track,key)
    if time>=original_length-.00001:continue
    clip.track_insert_key(track,time+float(repeat)*original_length,source.track_get_key_value(track,key))
 var head_track:=-1
 for track in source.get_track_count():
  if source.track_get_type(track)==Animation.TYPE_ROTATION_3D and String(source.track_get_path(track).get_concatenated_subnames())=="head":head_track=track
 var output_track:=head_track
 if output_track<0:
  output_track=clip.add_track(Animation.TYPE_ROTATION_3D)
  clip.track_set_path(output_track,NodePath(str(rig_path)+":head"))
 while clip.track_get_key_count(output_track)>0:clip.track_remove_key(output_track,0)
 for frame in 241:
  var time:=clip.length*float(frame)/240.0
  var phase:=TAU*time/clip.length
  var yaw:float={"boatman":.12,"dock_porter":.075,"record_clerk":.04}[role]*sin(phase)
  var pitch:float=.045*(1.0-cos(phase)) if role=="record_clerk" else .018*sin(phase*2.0)
  var pose:Quaternion=source.rotation_track_interpolate(head_track,fposmod(time,original_length)) if head_track>=0 else rig.get_bone_pose_rotation(rig.find_bone("head"))
  clip.rotation_track_insert_key(output_track,time,pose*Quaternion(Vector3.UP,yaw)*Quaternion(Vector3.RIGHT,pitch))
 clip.loop_mode=Animation.LOOP_LINEAR
 return clip
