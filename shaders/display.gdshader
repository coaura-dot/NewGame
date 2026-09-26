shader_type canvas_item;
render_mode unshaded;
// Exibe o mundo (renderizado em 320x180) ampliado na tela, com o
// pós-processamento. Cada efeito pode ser desligado em Opções > Vídeo.
// TEXTURE = mundo (nearest => pixels nítidos). world_lin = a mesma textura
// amostrada com filtro linear (para o borrão de movimento).

uniform sampler2D world_lin : filter_linear, repeat_disable;
uniform sampler2D bloom_tex : filter_linear, repeat_disable;
uniform float bloom_amount = 0.7;

uniform bool motion_blur_on = true;
uniform vec2 blur_vec = vec2(0.0);

uniform bool rays_on = true;
uniform vec2 ray_origin = vec2(0.8, -0.3);
uniform float ray_strength = 0.2;

uniform float chroma = 0.0;
uniform bool vignette_on = false;
uniform float vignette = 0.22;

uniform vec3 grade_tint = vec3(1.0);
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float hue_shift = 0.0;

uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fade = 0.0;
uniform vec4 fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec3 hue_rotate(vec3 c, float a) {
	const mat3 to_yiq = mat3(vec3(0.299, 0.596, 0.211), vec3(0.587, -0.274, -0.523), vec3(0.114, -0.322, 0.312));
	const mat3 to_rgb = mat3(vec3(1.0, 1.0, 1.0), vec3(0.956, -0.272, -1.106), vec3(0.621, -0.647, 1.703));
	vec3 yiq = to_yiq * c;
	float h = atan(yiq.z, yiq.y) + a;
	float cl = length(yiq.yz);
	return to_rgb * vec3(yiq.x, cl * cos(h), cl * sin(h));
}

void fragment() {
	vec2 uv = UV;
	vec3 col;
	if (chroma > 0.001) {
		vec2 d = (uv - 0.5) * chroma * 0.012;
		col = vec3(texture(TEXTURE, uv + d).r, texture(TEXTURE, uv).g, texture(TEXTURE, uv - d).b);
	} else {
		col = texture(TEXTURE, uv).rgb;
	}
	if (motion_blur_on && length(blur_vec) > 0.0004) {
		vec3 acc = col;
		float w = 1.0;
		for (int i = 1; i <= 6; i++) {
			float t = float(i) / 6.0;
			float k = 1.0 - t * 0.7;
			acc += texture(world_lin, uv - blur_vec * t).rgb * k;
			w += k;
		}
		col = acc / w;
	}
	vec3 bloom = texture(bloom_tex, uv).rgb;
	col += bloom * bloom_amount;
	if (rays_on && ray_strength > 0.001) {
		vec2 delta = (uv - ray_origin) / 20.0;
		vec2 p = uv;
		float decay = 1.0;
		vec3 r = vec3(0.0);
		for (int i = 0; i < 20; i++) {
			p -= delta;
			r += texture(bloom_tex, clamp(p, vec2(0.002), vec2(0.998))).rgb * decay;
			decay *= 0.9;
		}
		col += r * ray_strength * 0.1;
	}
	col *= grade_tint;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);
	col = max((col - 0.45) * contrast + 0.45, vec3(0.0));
	if (abs(hue_shift) > 0.001) {
		col = max(hue_rotate(col, hue_shift * 6.2831853), vec3(0.0));
	}
	if (vignette_on) {
		float v = smoothstep(0.95, 0.35, length((uv - 0.5) * vec2(1.2, 1.0)));
		col *= mix(1.0 - vignette, 1.0, v);
	}
	col = mix(col, flash_color.rgb, clamp(flash, 0.0, 1.0));
	col = mix(col, fade_color.rgb, fade);
	COLOR = vec4(col, 1.0);
}
