shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float dizzy_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float drunk_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float smoke_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float coma_fade : hint_range(0.0, 1.0) = 0.0;
uniform float fx_time = 0.0;

void fragment() {
	float total_fx = max(max(dizzy_intensity, drunk_intensity), max(smoke_intensity, coma_fade));
	
	if (total_fx <= 0.001) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		vec2 uv = SCREEN_UV;
		vec2 center = vec2(0.5, 0.5);
		vec2 to_center = uv - center;
		float dist = length(to_center);
		
		// --- 1. SMOKING HEAVY WEIRD WARP & DISTORTION ---
		float s_int = max(dizzy_intensity, smoke_intensity);
		vec2 warped_uv = uv;
		if (s_int > 0.01) {
			// Multi-layered chaotic wave ripples
			float w1 = sin(uv.y * 22.0 + fx_time * 5.5) * 0.035 * s_int;
			float w2 = cos(uv.x * 18.0 - fx_time * 4.2) * 0.030 * s_int;
			float swirl = sin(dist * 18.0 - fx_time * 3.8) * 0.025 * s_int;
			warped_uv += vec2(w1 + swirl, w2 - swirl);
		}
		
		// --- 2. DRUNK SWAY & STUMBLE ---
		if (drunk_intensity > 0.01) {
			vec2 drunk_sway = vec2(
				sin(fx_time * 2.4) * 0.028,
				cos(fx_time * 1.8) * 0.022
			) * drunk_intensity;
			warped_uv += drunk_sway;
		}
		
		// --- 3. EXTREME CHROMATIC ABERRATION ---
		float split = (0.012 + dist * 0.045) * s_int + 0.018 * drunk_intensity;
		float r = texture(screen_texture, warped_uv + vec2(split, 0.0)).r;
		float g = texture(screen_texture, warped_uv).g;
		float b = texture(screen_texture, warped_uv - vec2(split, 0.0)).b;
		vec3 base_col = vec3(r, g, b);
		
		// --- 4. DRUNK DOUBLE & TRIPLE VISION ---
		if (drunk_intensity > 0.05) {
			vec2 ghost1 = vec2(sin(fx_time * 3.0) * 0.035, cos(fx_time * 2.2) * 0.025) * drunk_intensity;
			vec2 ghost2 = vec2(-sin(fx_time * 2.5) * 0.030, -cos(fx_time * 3.2) * 0.020) * drunk_intensity;
			vec3 col_ghost1 = texture(screen_texture, warped_uv + ghost1).rgb;
			vec3 col_ghost2 = texture(screen_texture, warped_uv + ghost2).rgb;
			base_col = mix(base_col, (base_col + col_ghost1 + col_ghost2) * 0.38, drunk_intensity * 0.85);
		}
		
		// --- 5. HEAVY BILLOWING SMOKE CLOUD OVERLAY (REALLY HARD TO SEE) ---
		if (s_int > 0.02) {
			// Procedural billowy smoke noise
			float n1 = sin(uv.x * 9.0 + fx_time * 1.2) * cos(uv.y * 8.0 + fx_time * 1.6);
			float n2 = sin(uv.x * 19.0 - fx_time * 2.2) * cos(uv.y * 15.0 - fx_time * 1.9);
			float n3 = sin(uv.x * 35.0 + fx_time * 3.5) * cos(uv.y * 28.0 + fx_time * 3.0);
			float cloud = clamp((n1 * 0.5 + n2 * 0.3 + n3 * 0.2 + 0.75) * 0.70, 0.0, 1.0);
			
			// Thick smoke clouds drifting and obscuring everything
			vec3 smoke_tint = vec3(0.88, 0.90, 0.94);
			base_col = mix(base_col, smoke_tint, cloud * s_int * 0.75);
			
			// Psychedelic color shifts when high
			vec3 psycho = vec3(
				0.5 + 0.5 * sin(fx_time * 2.0 + uv.x * 4.0),
				0.5 + 0.5 * sin(fx_time * 2.5 + uv.y * 4.0),
				0.5 + 0.5 * cos(fx_time * 1.8 + dist * 6.0)
			);
			base_col = mix(base_col, base_col * psycho * 1.4, s_int * 0.30);
			
			// Heavy tunnel vision vignette
			float fog_vignette = smoothstep(0.95, 0.30, dist);
			base_col = mix(base_col * 0.3, base_col, mix(1.0, fog_vignette, s_int * 0.65));
		}
		
		// --- 6. COMA BLACKOUT FADE ---
		if (coma_fade > 0.001) {
			base_col = mix(base_col, vec3(0.0), clamp(coma_fade, 0.0, 1.0));
		}
		
		COLOR = vec4(base_col, 1.0);
	}
}
