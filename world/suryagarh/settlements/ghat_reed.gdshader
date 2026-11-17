shader_type spatial;
render_mode cull_disabled;

// Opaque interlaced reed matting. UVs span a two-metre screen panel.
void fragment() {
	vec2 weave = UV * vec2(110.0, 94.0);
	vec2 cell = floor(weave);
	vec2 strand = fract(weave);
	float over = mod(cell.x + cell.y, 2.0);
	float across = mix(strand.x, strand.y, over);
	float edge = smoothstep(0.01, 0.10, across) * (1.0 - smoothstep(0.90, 0.99, across));
	float fibre = sin((UV.x + UV.y * 0.09) * 2800.0) * 0.018;
	float variation = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = mix(vec3(0.16, 0.115, 0.062), vec3(0.43, 0.34, 0.19), edge) * (0.88 + variation * 0.20) + fibre;
	ROUGHNESS = 0.98;
}
