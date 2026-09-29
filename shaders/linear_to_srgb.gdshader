shader_type canvas_item;
// O mundo é renderizado em HDR linear (para o bloom); aqui ele é convertido
// para sRGB uma única vez ao ser mostrado na janela.
// Também faz o "pixel nítido": a textura é amostrada com filtro linear só na
// borda entre dois pixels (1 px de tela), então os pixels ficam quadrados e
// iguais mesmo em escalas não inteiras (ex.: 256x144 -> 1920x1080 = 7,5x).

void fragment() {
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 p = UV * tex_size;
	vec2 seam = floor(p + 0.5);
	vec2 dudv = max(fwidth(p), vec2(1e-5));
	p = seam + clamp((p - seam) / dudv, -0.5, 0.5);
	vec3 x = max(texture(TEXTURE, p / tex_size).rgb, vec3(0.0));
	vec3 lo = 12.92 * x;
	vec3 hi = 1.055 * pow(x, vec3(1.0 / 2.4)) - 0.055;
	COLOR = vec4(mix(lo, hi, step(vec3(0.0031308), x)), 1.0);
}
