shader_type canvas_item;
// O mundo é renderizado em HDR linear (para o bloom); aqui ele é convertido
// para sRGB uma única vez ao ser mostrado na janela.

void fragment() {
	vec3 x = max(texture(TEXTURE, UV).rgb, vec3(0.0));
	vec3 lo = 12.92 * x;
	vec3 hi = 1.055 * pow(x, vec3(1.0 / 2.4)) - 0.055;
	COLOR = vec4(mix(lo, hi, step(vec3(0.0031308), x)), 1.0);
}
