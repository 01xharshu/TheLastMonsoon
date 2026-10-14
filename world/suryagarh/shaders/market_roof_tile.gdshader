shader_type spatial;
render_mode cull_disabled;
void fragment(){
 vec2 tile=UV/vec2(.26,.42);
 float row=floor(tile.y);
 vec2 cell=fract(vec2(tile.x+mod(row,2.0)*.5,tile.y));
 vec2 filtering=max(fwidth(tile),vec2(.006));
 float side_seam=1.0-smoothstep(.018,.018+filtering.x,min(cell.x,1.0-cell.x));
 float overlap=1.0-smoothstep(.025,.025+filtering.y,cell.y);
 float variation=fract(sin(dot(floor(vec2(tile.x+mod(row,2.0)*.5,tile.y)),vec2(12.9898,78.233)))*43758.5453);
 ALBEDO=vec3(.36,.155,.072)*(.85+variation*.24)*(1.0-side_seam*.18-overlap*.2);
 NORMAL_MAP=normalize(vec3(sin(cell.x*6.283185)*.18,0.0,1.0))*.5+.5;
 ROUGHNESS=.94;
 SPECULAR=.12;
}
