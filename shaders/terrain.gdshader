shader_type canvas_item;
// Terreno (tiles de 16 px, ver tools/build_tiles.py).
//  * Pixels MAGENTA do atlas = "miolo": trocados pela textura grande do
//    material amostrada na posição do MUNDO (nada se repete a cada tile).
//    O verde do magenta codifica o brilho (chanfro claro/escuro das bordas).
//  * Profundidade: quanto mais longe do ar, mais escuro (mapa por célula com
//    filtro linear => degradê suave), como as massas de rocha do Hollow Knight.
//  * Normais: relevo do miolo + chanfro das bordas, para as luzes (tochas,
//    chama da Faísca, cristais) refletirem nas pedras.

uniform sampler2D fill_tex : filter_nearest, repeat_enable;
uniform sampler2D fill_normal : filter_nearest, repeat_enable;
uniform sampler2D edge_normal : filter_nearest;
uniform sampler2D depth_tex : filter_linear, repeat_disable;
uniform vec2 depth_size = vec2(1.0, 1.0); // células da fase
uniform float cell = 8.0;  // unidades do mundo por tile
uniform float art = 2.0;   // pixels de arte por unidade
uniform vec4 deep_color : source_color = vec4(0.045, 0.04, 0.06, 1.0);
uniform float depth_strength = 1.0;
uniform float fill_bright = 1.0;
uniform bool use_normals = true;

varying vec2 wpos;
varying vec4 vcol; // modulate da camada (o COLOR do fragment já vem multiplicado pela textura)

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vcol = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 apx = floor(wpos * art) + 0.5; // pixel de arte no mundo
	vec2 fsz = vec2(textureSize(fill_tex, 0));
	bool is_fill = c.r > 0.98 && c.b > 0.98 && c.g < 0.45;
	vec3 en = texture(edge_normal, UV).rgb * 2.0 - 1.0;
	vec3 n = en;
	if (is_fill) {
		float k = 0.5 + c.g * 255.0 / 100.0;
		c.rgb = texture(fill_tex, apx / fsz).rgb * k * fill_bright;
		vec3 fnm = texture(fill_normal, apx / fsz).rgb * 2.0 - 1.0;
		n = normalize(vec3(fnm.xy + en.xy, max(fnm.z * en.z, 0.2)));
	}
	if (depth_strength > 0.0) {
		float d = texture(depth_tex, wpos / (cell * depth_size)).r * depth_strength;
		c.rgb = mix(c.rgb, deep_color.rgb, clamp(d, 0.0, 0.96));
	}
	if (use_normals) {
		NORMAL_MAP = n * 0.5 + 0.5;
	}
	COLOR = c * vcol;
}
