shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
uniform sampler2D timber : source_color, filter_linear_mipmap, repeat_enable;

uniform vec4 tint : source_color = vec4(0.4,0.3,0.2,1.0);
uniform float surface_kind = 0.0;
uniform float base_roughness = 0.85;
varying vec3 local_at;
varying vec3 local_normal;
float noise(vec3 p) {
 vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 float a=fract(sin(dot(i,vec3(127.1,311.7,74.7)))*43758.5453);
 float b=fract(sin(dot(i+vec3(1,0,0),vec3(127.1,311.7,74.7)))*43758.5453);
 float c=fract(sin(dot(i+vec3(0,1,0),vec3(127.1,311.7,74.7)))*43758.5453);
 float d=fract(sin(dot(i+vec3(1,1,0),vec3(127.1,311.7,74.7)))*43758.5453);
 return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}
void vertex(){local_at=VERTEX;local_normal=NORMAL;}
void fragment(){
 vec3 p=local_at;
 vec3 weights=pow(abs(normalize(local_normal)),vec3(6.0));weights/=max(dot(weights,vec3(1.0)),0.001);
 vec2 ux=p.zy*vec2(0.22,0.9), uy=p.zx*vec2(0.22,0.9), uz=p.xy*vec2(0.9,0.22);
 vec3 grain=texture(timber,ux).rgb*weights.x+texture(timber,uy).rgb*weights.y+texture(timber,uz).rgb*weights.z;
 float mottling=noise(p*3.3), wear=noise(p*0.7);
 vec3 col=tint.rgb;
 if(surface_kind<0.5){float grain_value=dot(grain,vec3(0.299,0.587,0.114)); col*=0.62+grain_value*2.1;}
 else if(surface_kind<1.5){col*=0.72+0.48*mottling;col=mix(col,vec3(0.07,0.13,0.105),smoothstep(0.54,0.86,wear)*0.6);}
 else if(surface_kind<2.5){col*=0.76+0.35*mottling;float weave=sin(p.x*420.0)*sin(p.z*420.0);col*=1.0+weave*0.025;}
 else if(surface_kind<3.5){col*=0.82+0.25*mottling;col=mix(col,grain*0.5,smoothstep(0.68,0.88,wear)*0.25);}
 else {col*=0.7+0.5*mottling;}
 ALBEDO=col;
 ROUGHNESS=clamp(base_roughness+(wear-0.5)*0.15,0.35,1.0);
 METALLIC=surface_kind>0.5&&surface_kind<1.5?0.45:0.0;
 // UV-independent micrograin; geometric normals retain orientation at joins.
 
}
