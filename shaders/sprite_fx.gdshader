shader_type canvas_item;
// Efeitos de sprite: flash de dano (HDR -> bloom), contorno com a cor do
// status ativo (queimando, sangrando, congelado...) e dissolução ao morrer.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_boost = 2.4;
uniform vec4 status_color = vec4(0.0);
uniform float status_strength = 0.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dissolve_color = vec4(3.0, 1.2, 0.4, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	vec2 px = TEXTURE_PIXEL_SIZE;
	float n = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	float inside = step(0.1, c.a);
	float outline = step(0.1, n) * (1.0 - inside);
	vec3 col = mix(c.rgb, flash_color.rgb * flash_boost, flash * inside);
	col += status_color.rgb * status_strength * 0.25 * inside;
	vec3 rgb = mix(status_color.rgb * 1.6, col, inside);
	float a = max(c.a, outline * status_strength);
	if (dissolve > 0.0) {
		float h = hash(floor(UV / px));
		if (h < dissolve) {
			a = 0.0;
		} else if (h < dissolve + 0.08) {
			rgb = dissolve_color.rgb;
		}
	}
	COLOR = vec4(rgb, a);
}
