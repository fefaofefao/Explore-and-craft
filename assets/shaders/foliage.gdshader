shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled, cull_back;
// Vegetação e objetos com cor por vértice. O alfa da cor é o "peso do vento" (0 = parado).
// Segue o vento global (direção, força e rajadas).

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 wind_dir = vec2(1.0, 0.0);
uniform float wind_str = 0.5;
uniform vec2 wind_offset = vec2(0.0);
uniform float wind_speed = 1.3;
uniform float rim_amount = 0.18;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float w = COLOR.a;
	float gust = smoothstep(0.4, 0.85, texture(noise_tex, (wp.xz - wind_offset) * 0.02).r);
	float ph = TIME * wind_speed * (0.8 + wind_str) + wp.x * 0.13 + wp.z * 0.11;
	float sway = (wind_str * 0.35 + gust * 0.6) + sin(ph) * 0.18 * (0.4 + wind_str);
	vec3 local_dir = (inverse(MODEL_MATRIX) * vec4(wind_dir.x, 0.0, wind_dir.y, 0.0)).xyz;
	VERTEX.xz += local_dir.xz * sway * 0.12 * w * VERTEX.y;
	VERTEX += NORMAL * sin(TIME * (3.0 + wind_str * 4.0) + VERTEX.y * 2.0 + wp.x) * 0.015 * w * (0.6 + wind_str);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = COLOR.rgb * rim * rim_amount * COLOR.a;
	ROUGHNESS = 1.0;
}
