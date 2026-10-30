shader_type canvas_item;
// Minimapa circular que gira com a câmera.
uniform sampler2D map_tex : filter_linear;
uniform vec2 center_uv = vec2(0.5);
uniform float zoom = 0.2;
uniform float angle = 0.0;

void fragment() {
	vec2 p = UV - 0.5;
	float d = length(p);
	if (d > 0.5) discard;
	float c = cos(angle);
	float s = sin(angle);
	vec2 r = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	vec2 uv = center_uv + r * zoom * 2.0;
	vec4 col = texture(map_tex, uv);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) col = vec4(0.12, 0.3, 0.45, 1.0);
	float edge = smoothstep(0.44, 0.5, d);
	col.rgb = mix(col.rgb, vec3(0.06, 0.08, 0.12), edge * 0.9);
	col.rgb *= 1.0 - smoothstep(0.3, 0.5, d) * 0.25;
	COLOR = vec4(col.rgb, 1.0);
}
