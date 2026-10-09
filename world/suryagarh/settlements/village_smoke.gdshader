shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX *= mat4(vec4(length(MODEL_MATRIX[0].xyz),0,0,0),vec4(0,length(MODEL_MATRIX[1].xyz),0,0),vec4(0,0,length(MODEL_MATRIX[2].xyz),0),vec4(0,0,0,1));
}
void fragment() {
	vec2 p=UV*2.0-1.0;
	float edge=1.0-smoothstep(.12,1.0,length(p));
	float wisps=.78+.22*sin(UV.x*19.0+UV.y*13.0+TIME*.6);
	ALBEDO=COLOR.rgb;
	ALPHA=COLOR.a*edge*wisps;
}
