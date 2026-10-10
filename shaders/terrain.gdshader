shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform vec3 grass_light : source_color = vec3(0.45, 0.70, 0.27);
uniform vec3 grass_dark : source_color = vec3(0.27, 0.52, 0.22);
uniform vec3 dirt : source_color = vec3(0.55, 0.45, 0.30);
uniform vec3 rock : source_color = vec3(0.50, 0.50, 0.55);
uniform vec3 snow : source_color = vec3(0.93, 0.95, 1.0);
uniform vec3 sand : source_color = vec3(0.80, 0.73, 0.55);
uniform vec3 road_color : source_color = vec3(0.68, 0.57, 0.40);
uniform vec2 road_points[16];
uniform int road_count = 0;
uniform float road_width = 2.2;

varying vec3 world_pos;
varying vec3 world_normal;

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

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = world_pos.xz;
	float n = noise(p * 0.05) * 0.6 + noise(p * 0.21) * 0.4;
	float slope = 1.0 - world_normal.y;
	vec3 col = mix(grass_dark, grass_light, smoothstep(0.3, 0.7, n));
	col = mix(col, dirt, smoothstep(0.22, 0.34, slope));
	col = mix(col, rock, smoothstep(0.38, 0.5, slope));
	col = mix(col, rock, smoothstep(24.0, 32.0, world_pos.y + n * 6.0));
	float snow_mask = smoothstep(40.0, 46.0, world_pos.y + n * 8.0) * (1.0 - smoothstep(0.55, 0.75, slope));
	col = mix(col, snow, snow_mask);
	col = mix(col, sand, 1.0 - smoothstep(1.0, 1.7, world_pos.y));

	float d = 1e6;
	for (int i = 0; i < road_count - 1; i++) {
		d = min(d, segment_distance(p, road_points[i], road_points[i + 1]));
	}
	float road = 1.0 - smoothstep(road_width - 0.5, road_width + 0.3, d + (noise(p * 0.7) - 0.5) * 0.8);
	col = mix(col, road_color * (0.9 + 0.2 * noise(p * 1.3)), road);

	ALBEDO = col;
	ROUGHNESS = 1.0;
}
