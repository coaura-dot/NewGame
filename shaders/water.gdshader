shader_type canvas_item;
// Água com reflexo (Kingdom Two Crowns): espelha o que está ACIMA da
// superfície (lido da tela), ondulado e quebrado em linhas horizontais,
// tingido com a cor da água. A linha da superfície brilha.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec4 water_color : source_color = vec4(0.22, 0.36, 0.46, 0.78);
uniform float surface_y = 0.5; // y da superfície em SCREEN_UV
uniform float px_h = 0.0069; // 1 pixel em SCREEN_UV (1/altura da tela)
uniform float reflect_strength = 0.6;

void fragment() {
	vec2 uv = SCREEN_UV;
	float d = uv.y - surface_y;
	float wave = sin(uv.y * 900.0 + TIME * 4.0) * px_h * 0.9 + sin(uv.x * 260.0 + TIME * 1.6) * px_h * 0.35;
	vec2 ruv = vec2(uv.x + wave, surface_y - d - px_h);
	vec3 refl = texture(screen_tex, clamp(ruv, vec2(0.001), vec2(0.999))).rgb;
	vec3 col = mix(water_color.rgb, refl * mix(vec3(1.0), water_color.rgb * 1.8, 0.5), reflect_strength);
	// linhas quebradas que correm devagar
	float row = floor(uv.y / px_h);
	float gap = step(0.72, fract(sin(row * 12.9898 + floor(uv.x / px_h / 6.0 + TIME * 0.8 + row) * 4.1) * 43758.5));
	col = mix(col, water_color.rgb * 1.25, gap * 0.45);
	// superfície
	if (d < px_h * 1.2) {
		col = mix(col, vec3(1.0, 1.0, 1.05), 0.55);
	}
	COLOR = vec4(col, water_color.a);
}
