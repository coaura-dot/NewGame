shader_type canvas_item;
// Pós-processamento em uma passada. Cada efeito pode ser desligado no menu
// de vídeo (o script PostFX liga/desliga os uniforms). O bloom vem do
// WorldEnvironment (glow HDR), não daqui.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform bool motion_blur_on = true;
uniform vec2 blur_vec = vec2(0.0);
uniform float dash_blur = 0.0;
uniform vec2 dash_center = vec2(0.5);

uniform bool rays_on = true;
uniform vec2 ray_origin = vec2(0.5, -0.1);
uniform float ray_strength = 0.3;
uniform float ray_threshold = 1.05;
uniform float ray_length = 0.12;

uniform float chroma = 0.0;

uniform bool vignette_on = true;
uniform float vignette = 0.35;
uniform bool grain_on = true;
uniform float grain = 0.03;

uniform vec3 grade_tint = vec3(1.0);
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float hue_shift = 0.0;

uniform float fade = 0.0;
uniform vec4 fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec3 hue_rotate(vec3 c, float a) {
	const mat3 to_yiq = mat3(vec3(0.299, 0.596, 0.211), vec3(0.587, -0.274, -0.523), vec3(0.114, -0.322, 0.312));
	const mat3 to_rgb = mat3(vec3(1.0, 1.0, 1.0), vec3(0.956, -0.272, -1.106), vec3(0.621, -0.647, 1.703));
	vec3 yiq = to_yiq * c;
	float h = atan(yiq.z, yiq.y) + a;
	float chroma_len = length(yiq.yz);
	return to_rgb * vec3(yiq.x, chroma_len * cos(h), chroma_len * sin(h));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col;
	if (chroma > 0.001) {
		vec2 d = (uv - 0.5) * chroma * 0.018;
		col = vec3(texture(screen_tex, uv + d).r, texture(screen_tex, uv).g, texture(screen_tex, uv - d).b);
	} else {
		col = texture(screen_tex, uv).rgb;
	}

	if (motion_blur_on && (length(blur_vec) > 0.0004 || dash_blur > 0.001)) {
		vec3 acc = col;
		float w = 1.0;
		for (int i = 1; i <= 8; i++) {
			float t = float(i) / 8.0;
			vec2 off = blur_vec * t + (uv - dash_center) * dash_blur * 0.07 * t;
			acc += texture(screen_tex, uv - off).rgb * (1.0 - t * 0.5);
			w += 1.0 - t * 0.5;
		}
		col = acc / w;
	}

	if (rays_on && ray_strength > 0.0) {
		// Raios curtos e suaves: só pixels HDR (luz emissiva > 1.0) espalham
		// luz para longe da origem, por um trecho curto e com jitter por
		// pixel (sem isso, a 320x180 os passos viram "contas" pontilhadas).
		const int RAY_STEPS = 20;
		vec2 delta = (uv - ray_origin) * ray_length / float(RAY_STEPS);
		float jitter = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		vec2 p = uv - delta * jitter;
		float decay = 1.0;
		vec3 rays = vec3(0.0);
		for (int i = 0; i < RAY_STEPS; i++) {
			p -= delta;
			vec3 s = texture(screen_tex, clamp(p, vec2(0.001), vec2(0.999))).rgb;
			float lum = dot(s, vec3(0.299, 0.587, 0.114));
			rays += s * max(lum - ray_threshold, 0.0) * decay;
			decay *= 0.88;
		}
		col += rays * ray_strength / float(RAY_STEPS);
	}

	col *= grade_tint;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);
	col = max((col - 0.35) * contrast + 0.35, vec3(0.0));
	if (abs(hue_shift) > 0.001) {
		col = max(hue_rotate(col, hue_shift * 6.2831853), vec3(0.0));
	}

	if (vignette_on) {
		float v = smoothstep(0.95, 0.3, length((uv - 0.5) * vec2(1.25, 1.0)));
		col *= mix(1.0 - vignette, 1.0, v);
	}
	if (grain_on) {
		float n = fract(sin(dot(uv * (TIME + 1.0), vec2(12.9898, 78.233))) * 43758.5453);
		col += (n - 0.5) * grain;
	}
	col = mix(col, fade_color.rgb, fade);
	COLOR = vec4(col, 1.0);
}
