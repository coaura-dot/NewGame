shader_type canvas_item;
render_mode unshaded;
// Bloom em meia resolução: pega só o que passa de "threshold" (cores HDR —
// magias, cortes, lanternas) e borra num disco suave. O resultado é somado
// na tela pelo display.gdshader.

uniform sampler2D src : filter_linear, repeat_disable;
uniform float threshold = 1.0;
uniform float radius = 7.0;

void fragment() {
	vec2 px = 1.0 / vec2(textureSize(src, 0));
	vec3 acc = vec3(0.0);
	float w = 0.0;
	for (int i = 0; i < 40; i++) {
		float fi = float(i) + 0.5;
		float r = sqrt(fi / 40.0) * radius;
		float a = fi * 2.39996;
		vec2 o = vec2(cos(a), sin(a)) * r * px * 2.0;
		vec3 s = texture(src, UV + o).rgb;
		float k = 1.0 - r / (radius + 1.0);
		acc += max(s - vec3(threshold), vec3(0.0)) * k;
		w += k;
	}
	COLOR = vec4(acc / w * 2.4, 1.0);
}
