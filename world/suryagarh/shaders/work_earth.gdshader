shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
uniform sampler2D earth_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 point;
void vertex(){point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float fleck=fract(sin(dot(floor(point.xz*8.0),vec2(12.9898,78.233)))*43758.5453);
 float edge=max(abs(UV.x-.5)*2.0,abs(UV.y-.5)*2.0);
 ALBEDO=texture(earth_texture,point.xz/3.0).rgb*vec3(.83,.76,.63);
 ALPHA=1.0-smoothstep(.62+fleck*.14,.98,edge);
 ROUGHNESS=.97;
 SPECULAR=.12;
}
