shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
// Sobreposição de destaque: borda (fresnel) brilhante que pulsa, usada no alvo de interação.
uniform vec4 glow_color : source_color = vec4(1.0, 0.9, 0.45, 1.0);
uniform float strength = 0.9;

void fragment() {
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float pulse = 0.55 + 0.45 * sin(TIME * 5.0);
	ALBEDO = glow_color.rgb * (fr * 1.4 + 0.12) * pulse * strength;
}
