shader_type canvas_item;
render_mode blend_add;
// Feixe de luz volumétrico (raios de janela/claraboia) no espaço do mundo.
// Desenhado num ColorRect: estreito em cima, alargando para baixo, com
// faixas animadas e poeira brilhando.

uniform vec4 color = vec4(1.4, 1.25, 0.95, 1.0);
uniform float intensity = 0.28;
uniform float top_width = 0.35;
uniform float skew = 0.18;
uniform float speed = 0.25;
uniform float seed = 0.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(i + seed), hash(i + 1.0 + seed), smoothstep(0.0, 1.0, f));
}

void fragment() {
	vec2 uv = UV;
	float center = 0.5 + skew * uv.y;
	float half_w = mix(top_width, 1.0, uv.y) * 0.5 * (1.0 - skew * 0.5);
	float dx = abs(uv.x - center) / max(half_w, 0.001);
	float shape = smoothstep(1.0, 0.55, dx);
	float bands = 0.55 + 0.45 * noise((uv.x - skew * uv.y) * 18.0 + TIME * speed * 3.0)
		* noise((uv.x - skew * uv.y) * 7.0 - TIME * speed);
	float fade = pow(1.0 - uv.y, 1.3) * smoothstep(0.0, 0.08, uv.y);
	float dust = step(0.985, hash(floor(uv.x * 90.0) + floor(uv.y * 60.0 - TIME * 3.0) * 13.0)) * shape;
	float a = shape * bands * fade * intensity + dust * 0.6 * fade;
	COLOR = vec4(color.rgb * a, 1.0);
}
