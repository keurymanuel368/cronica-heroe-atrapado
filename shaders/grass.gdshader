shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform vec3 grass_light : source_color = vec3(0.40, 0.66, 0.28);
uniform vec3 grass_dark : source_color = vec3(0.26, 0.50, 0.24);
uniform vec3 path_color : source_color = vec3(0.66, 0.55, 0.38);
uniform float path_width = 2.2;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float n = noise(p * 0.07) * 0.65 + noise(p * 0.3) * 0.35;
	vec3 col = mix(grass_dark, grass_light, smoothstep(0.35, 0.65, n));
	// Camino de tierra que sale del punto de inicio hacia el norte.
	float wiggle = sin(p.y * 0.12) * 3.0;
	float d = abs(p.x - wiggle);
	float on_path = (1.0 - smoothstep(path_width - 0.4, path_width, d)) * step(p.y, 4.0);
	on_path = max(on_path, 1.0 - smoothstep(5.5, 6.2, length(p)));
	col = mix(col, path_color * (0.92 + 0.16 * noise(p * 0.8)), on_path);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
