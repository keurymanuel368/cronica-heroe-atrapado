shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;

uniform vec3 base_color : source_color = vec3(0.20, 0.42, 0.16);
uniform vec3 tip_color : source_color = vec3(0.62, 0.84, 0.36);
uniform float sway = 0.22;

varying float tip;
varying vec3 tint;

void vertex() {
	tip = UV.y;
	tint = INSTANCE_CUSTOM.rgb;
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float wind = sin(TIME * 1.4 + world.x * 0.12 + world.z * 0.09) * 0.6
		+ sin(TIME * 2.9 + world.x * 0.55 + world.z * 0.3) * 0.25;
	VERTEX.x += wind * sway * UV.y * UV.y;
	VERTEX.z += wind * sway * 0.4 * UV.y * UV.y;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	ALBEDO = mix(base_color, tip_color, tip) * tint;
	ROUGHNESS = 1.0;
}
