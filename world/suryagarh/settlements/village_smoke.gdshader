shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
global uniform vec3 world_wind;
varying vec2 puff_offset;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
 puff_offset=MODEL_MATRIX[3].xz*.37;
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
 MODELVIEW_MATRIX *= mat4(vec4(length(MODEL_MATRIX[0].xyz),0,0,0),vec4(0,length(MODEL_MATRIX[1].xyz),0,0),vec4(0,0,length(MODEL_MATRIX[2].xyz),0),vec4(0,0,0,1));
}
void fragment() {
 vec2 p=UV*2.0-1.0;
 vec2 phase=vec2(world_wind.y*.07,-world_wind.y*.11)+puff_offset;
 float coarse=noise(UV*4.0+phase);
 float fine=noise(UV*9.0-phase*.7);
 float edge=1.0-smoothstep(.18,1.0,length(p)+.16*(coarse-.5));
 ALBEDO=COLOR.rgb;
 ALPHA=COLOR.a*edge*smoothstep(.12,.78,coarse*.72+fine*.28);
}
