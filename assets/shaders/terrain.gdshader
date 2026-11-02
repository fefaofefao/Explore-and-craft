shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;
// Terreno estilizado: mistura grama/terra/areia/rocha/topo por altura, inclinação e ruído em espaço de mundo.

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform float map_half = 120.0;
uniform vec4 deep_tint : source_color = vec4(0.12, 0.32, 0.38, 1.0);
uniform vec4 grass_a : source_color = vec4(0.31, 0.56, 0.23, 1.0);
uniform vec4 grass_b : source_color = vec4(0.53, 0.76, 0.35, 1.0);
uniform vec4 grass_c : source_color = vec4(0.42, 0.67, 0.27, 1.0);
uniform vec4 dirt : source_color = vec4(0.55, 0.42, 0.28, 1.0);
uniform vec4 sand : source_color = vec4(0.9, 0.83, 0.6, 1.0);
uniform vec4 rock : source_color = vec4(0.49, 0.48, 0.45, 1.0);
uniform vec4 high : source_color = vec4(0.6, 0.64, 0.54, 1.0);
uniform float water_level = 0.0;
uniform float high_line = 20.0;
uniform float dirt_amount = 0.35;
uniform float rock_slope = 0.42;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 n1 = texture(noise_tex, wpos.xz * 0.006);
	vec4 n2 = texture(noise_tex, wpos.xz * 0.03);
	vec4 n3 = texture(noise_tex, wpos.xz * 0.21);
	float slope = 1.0 - clamp(wnorm.y, 0.0, 1.0);
	float h = wpos.y;
	// grama com manchas grandes e médias
	vec3 g = mix(grass_a.rgb, grass_b.rgb, smoothstep(0.3, 0.7, n1.r));
	g = mix(g, grass_c.rgb, smoothstep(0.45, 0.75, n2.g) * 0.6);
	// terra/trilhas
	float dm = smoothstep(0.62, 0.72, n2.r * 0.55 + n1.g * 0.45 + dirt_amount * 0.2 - 0.05);
	vec3 col = mix(g, dirt.rgb * (0.85 + n3.b * 0.3), dm * dirt_amount * 2.0);
	// pedrinhas (células)
	float pebble = 1.0 - smoothstep(0.0, 0.08, n3.a);
	col = mix(col, rock.rgb * 1.1, pebble * 0.35 * (1.0 - dm * 0.5));
	// areia na costa, com borda irregular e areia molhada
	float shore = 1.0 - smoothstep(water_level + 0.9, water_level + 1.8, h + (n2.b - 0.5) * 0.9);
	vec3 sandc = sand.rgb * (0.92 + n3.r * 0.16);
	sandc *= mix(0.72, 1.0, smoothstep(water_level - 0.2, water_level + 0.45, h));
	col = mix(col, sandc, shore);
	// topo (neve, rocha clara...)
	float hi = smoothstep(high_line - 1.5, high_line + 1.5, h + (n2.r - 0.5) * 4.0);
	col = mix(col, high.rgb * (0.93 + n3.g * 0.14), hi);
	// rocha nas encostas, com estratos
	float rs = smoothstep(rock_slope - 0.06, rock_slope + 0.06, slope + (n2.g - 0.5) * 0.12);
	vec3 rc = rock.rgb * (0.82 + 0.18 * sin(h * 2.6 + n2.r * 5.0)) * (0.9 + n3.b * 0.2);
	col = mix(col, rc, rs);
	// micro variação e oclusão nas reentrâncias
	col *= 0.9 + n3.r * 0.2;
	col *= mix(0.82, 1.0, clamp(wnorm.y * 1.3, 0.0, 1.0));
	// oclusão de vales: compara a altura local com a média ao redor (mapa de alturas)
	vec2 huv = (wpos.xz + vec2(map_half)) / (2.0 * map_half);
	float px = 3.0 / 129.0;
	float avg = (texture(height_tex, huv + vec2(px, 0.0)).r + texture(height_tex, huv - vec2(px, 0.0)).r
		+ texture(height_tex, huv + vec2(0.0, px)).r + texture(height_tex, huv - vec2(0.0, px)).r) * 0.25;
	float cavity = clamp((avg - texture(height_tex, huv).r) * 16.0 * 0.55, 0.0, 0.38);
	col *= 1.0 - cavity;
	// manchas de luz/sombra grandes (pintura) e sombras de nuvens passando
	col *= 0.94 + n1.b * 0.12;
	float cloud = smoothstep(0.52, 0.78, texture(noise_tex, wpos.xz * 0.0035 + vec2(TIME * 0.004, TIME * 0.0025)).r);
	col *= 1.0 - cloud * 0.2;
	// fundo submerso: escurece e tinge conforme a profundidade (dá volume à água)
	float under = clamp((water_level - 0.15 - h) / 4.0, 0.0, 1.0);
	col = mix(col, deep_tint.rgb * (0.6 + n2.r * 0.3), under * 0.85);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
