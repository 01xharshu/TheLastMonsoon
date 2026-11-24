shader_type spatial;
uniform vec4 cloth_color : source_color = vec4(.57,.43,.26,1.0);
varying vec3 local_position;
void vertex(){local_position=VERTEX;}
void fragment(){
 float course=local_position.y/0.032+local_position.x*.4;
 float fade=1.0-smoothstep(.15,.7,abs(dFdx(course))+abs(dFdy(course)));
 float fold=sin(course*6.283185)*fade;
 ALBEDO=cloth_color.rgb*(1.0+fold*.055);
 ROUGHNESS=.9;
 SPECULAR=.2;
 vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX);
 vec3 rx=cross(dy,NORMAL),ry=cross(NORMAL,dx);
 float determinant=dot(dx,rx);
 float height=fold*.0005;
 vec3 gradient=(dFdx(height)*rx+dFdy(height)*ry)/max(abs(determinant),.000001)*sign(determinant);
 NORMAL=normalize(NORMAL-gradient);
}
