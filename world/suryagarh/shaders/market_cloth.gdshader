shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(.66,.54,.35,1.0);
varying vec3 cloth_point;
void vertex(){cloth_point=VERTEX;}
void fragment(){
 float warp=sin(cloth_point.x*430.0)*sin(cloth_point.z*430.0);
 float seam=1.0-smoothstep(.008,.02,abs(fract(UV.x*4.0)-.5));
 float stain=sin(cloth_point.x*1.7+cloth_point.z*2.1)*.04;
 ALBEDO=tint.rgb*(.96+warp*.035+stain-seam*.12);
 ROUGHNESS=.98;
 SPECULAR=.12;
}
