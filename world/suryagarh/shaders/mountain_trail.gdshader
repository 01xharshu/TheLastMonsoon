shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;
uniform sampler2D grain : source_color, repeat_enable;
varying vec3 world_position;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float irregular=sin(world_position.x*2.3+sin(world_position.z*1.7))*0.05;
 float edge=smoothstep(0.0,0.23,UV.x+irregular)*smoothstep(0.0,0.23,1.0-UV.x-irregular);
 vec3 gravel=texture(grain,world_position.xz*0.32).rgb;
 ALBEDO=mix(vec3(0.23,0.165,0.095),gravel*vec3(0.70,0.56,0.37),0.38);
 ROUGHNESS=1.0;
 ALPHA=edge*0.97;
}
