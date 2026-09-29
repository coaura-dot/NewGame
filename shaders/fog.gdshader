shader_type canvas_item;
render_mode unshaded;
// Névoa em pixel art: ruído que anda devagar, quantizado em poucos degraus
// com dither ordenado (sem borrão). Mais densa embaixo (band) e presa à tela.
// "scroll" = deslocamento da câmera * fator de parallax (passado pelo script).

uniform vec4 fog_color : source_color = vec4(0.3, 0.35, 0.5, 1.0);
uniform float density = 0.35;
uniform float band_top = 0.45;   // onde a névoa começa (0 = topo da tela)
uniform float band_soft = 0.4;   // quão suave é a entrada
uniform vec2 scroll = vec2(0.0);
uniform float speed = 0.02;
uniform float scale = 1.0;
uniform vec2 px_size = vec2(324.0, 184.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += noise(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 pix = floor(UV * px_size);
	vec2 p = (pix + scroll) / (60.0 * scale);
	float t = TIME * speed;
	float n = fbm(p + vec2(t, t * 0.3)) * 0.65 + fbm(p * 0.5 - vec2(t * 0.6, 0.0)) * 0.35;
	float band = smoothstep(band_top, band_top + band_soft, UV.y);
	float a = clamp((n - 0.35) * 1.8, 0.0, 1.0) * band * density;
	// quantiza em degraus (bordas nítidas de pixel art, sem pontilhado)
	a = floor(a * 6.0 + 0.5) / 6.0;
	COLOR = vec4(fog_color.rgb, a * fog_color.a);
}
