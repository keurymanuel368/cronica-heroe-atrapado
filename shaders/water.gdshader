shader_type spatial;
render_mode blend_mix, diffuse_toon, specular_toon, cull_disabled;

uniform vec3 deep : source_color = vec3(0.12, 0.42, 0.62);
uniform vec3 shallow : source_color = vec3(0.35, 0.72, 0.85);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float w = sin(p.x * 0.35 + TIME * 1.2) * sin(p.y * 0.3 - TIME * 0.9);
	float sparkle = smoothstep(0.82, 0.95, sin(p.x * 1.7 + TIME * 2.0) * sin(p.y * 1.5 + TIME * 1.6));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 col = mix(deep, shallow, 0.5 + 0.25 * w);
	col = mix(col, vec3(0.85, 0.95, 1.0), fres * 0.6 + sparkle * 0.5);
	ALBEDO = col;
	ROUGHNESS = 0.2;
	SPECULAR = 0.6;
	ALPHA = 0.88;
}
