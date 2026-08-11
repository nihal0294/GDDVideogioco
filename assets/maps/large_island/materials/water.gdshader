shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.08, 0.58, 0.68, 0.78);
uniform vec4 deep_color : source_color = vec4(0.015, 0.19, 0.38, 0.88);
uniform float wave_height : hint_range(0.0, 1.0) = 0.22;
uniform float wave_speed : hint_range(0.0, 3.0) = 0.75;
uniform vec2 island_half_extent = vec2(144.0, 144.0);

varying float wave_value;
varying vec2 surface_position;

void vertex() {
	surface_position = VERTEX.xz;
	float first_wave = sin(VERTEX.x * 0.13 + TIME * wave_speed);
	float second_wave = cos(VERTEX.z * 0.11 - TIME * wave_speed * 0.72);
	float diagonal_wave = sin((VERTEX.x + VERTEX.z) * 0.055 + TIME * wave_speed * 0.46);
	wave_value = (first_wave + second_wave + diagonal_wave) / 3.0;
	VERTEX.y += wave_value * wave_height;
}

void fragment() {
	float normalized_distance = length(surface_position / island_half_extent);
	float depth_mix = smoothstep(0.96, 1.08, normalized_distance);
	float wave_highlight = wave_value * 0.035;
	ALBEDO = mix(shallow_color.rgb, deep_color.rgb, depth_mix) + wave_highlight;
	ROUGHNESS = 0.18;
	METALLIC = 0.05;
	SPECULAR = 0.75;
	ALPHA = mix(shallow_color.a, deep_color.a, depth_mix);
}
