extends RefCounted
## Prepare cached 16-bit PCM once; avoid clicks and silent fades at loop seams.
static func prepare(source: AudioStreamWAV, loop: bool = false) -> AudioStreamWAV:
 var stream := source.duplicate() as AudioStreamWAV
 if stream.format != AudioStreamWAV.FORMAT_16_BITS: return stream
 var channels := 2 if stream.stereo else 1
 var bytes := stream.data
 var frames := bytes.size() / (2 * channels)
 if loop:
  var overlap := mini(int(stream.mix_rate * .15),int(frames / 4))
  var result := bytes.slice(overlap * channels * 2)
  # Tail flows into the head, then resumes just beyond that head segment.
  for frame in overlap:
   var mix := float(frame) / maxf(1.0,overlap-1.0)
   mix = mix * mix * (3.0-2.0*mix)
   for channel in channels:
    var end_index := ((frames-overlap+frame)*channels+channel)*2
    var head_index := (frame*channels+channel)*2
    var value := roundi(lerpf(bytes.decode_s16(end_index),bytes.decode_s16(head_index),mix))
    result.encode_s16(end_index-overlap*channels*2,value)
  stream.data = result
  stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
  stream.loop_begin = 0
  stream.loop_end = frames-overlap
 else:
  var fade := mini(int(stream.mix_rate*.012),int(frames/4))
  for frame in fade:
   var gain := float(frame)/maxf(1.0,fade-1.0)
   gain = gain*gain*(3.0-2.0*gain)
   for channel in channels:
    for position in [frame,frames-1-frame]:
     var index: int = (position*channels+channel)*2
     bytes.encode_s16(index,roundi(bytes.decode_s16(index)*gain))
  stream.data = bytes
 return stream
