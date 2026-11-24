shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 hair_color : source_color = vec4(.12,.09,.07,1.0);
void fragment() {
 vec2 strand_uv=vec2(UV.x*180.0+sin(UV.y*18.0)*.12,UV.y);
 float fade=1.0-smoothstep(.12,.65,length(dFdx(strand_uv))+length(dFdy(strand_uv)));
 float strand=sin(strand_uv.x*6.283185)*fade;
 float tone=sin(UV.x*31.0+UV.y*13.0)*.035;
 ALBEDO=hair_color.rgb*(1.0+tone+strand*.065);
 ROUGHNESS=.86;
 SPECULAR=.25;
 // Small strand relief follows the existing smooth beard surface.
 vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX);
 vec3 rx=cross(dy,NORMAL),ry=cross(NORMAL,dx);
 float determinant=dot(dx,rx);
 float height=strand*.00018;
 vec3 gradient=(dFdx(height)*rx+dFdy(height)*ry)/max(abs(determinant),.000001)*sign(determinant);
 NORMAL=normalize(NORMAL-gradient);
}
