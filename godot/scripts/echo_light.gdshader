shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

// The darkness, the light carried by sound waves, and the wave fronts themselves.
//
// Each active sound wave has a "distance field": a small texture that stores, for every
// spot in the level, how far sound has to travel through the corridors to get there.
// A spot lights up when the wave front reaches it, then fades as the front moves on.

uniform sampler2D f0 : filter_linear, repeat_disable;
uniform sampler2D f1 : filter_linear, repeat_disable;
uniform sampler2D f2 : filter_linear, repeat_disable;
uniform sampler2D f3 : filter_linear, repeat_disable;
uniform sampler2D f4 : filter_linear, repeat_disable;
uniform sampler2D f5 : filter_linear, repeat_disable;

uniform vec4 wave[6];      // x = how far the front has travelled (px), y = its reach, z = strength (0 = unused), w = length of the fading tail (px)
uniform vec4 wcol[6];      // rgb = colour of the wave lines, a = 1 for a plain circle with no maze (title screen)
uniform vec2 worigin[6];   // where the sound started
uniform vec4 glow[16];     // small steady lights: xy = position, z = radius, w = strength
uniform int glow_n = 0;
uniform vec2 rect_origin;  // the part of the world this rectangle covers
uniform vec2 rect_size;
uniform vec2 level_size = vec2(1.0);
uniform float ambient = 0.0;   // 0 = pitch dark, 1 = fully lit

float field(int i, vec2 uv) {
	if (i == 0) return texture(f0, uv).r;
	if (i == 1) return texture(f1, uv).r;
	if (i == 2) return texture(f2, uv).r;
	if (i == 3) return texture(f3, uv).r;
	if (i == 4) return texture(f4, uv).r;
	return texture(f5, uv).r;
}

void fragment() {
	vec2 world = rect_origin + UV * rect_size;
	vec2 fuv = world / level_size;
	float light = ambient;
	vec3 lines = vec3(0.0);

	for (int i = 0; i < 6; i++) {
		vec4 w = wave[i];
		if (w.z <= 0.0) continue;
		float d = wcol[i].a > 0.5 ? distance(world, worigin[i]) : field(i, fuv);
		if (d > w.y) continue;          // the sound never gets this far
		float behind = w.x - d;          // how far behind the wave front this spot is
		if (behind < 0.0) continue;      // the wave has not arrived yet
		float reach = 1.0 - 0.55 * d / w.y;                // sound gets weaker with distance
		light += w.z * reach * smoothstep(0.0, 10.0, behind) * exp(-behind / w.w);
		// the wave front: one sharp crest, then weaker ripples trailing behind it
		float alive = clamp(1.0 - w.x / w.y, 0.0, 1.0);
		float crest = exp(-behind * behind / 5.0);
		float ripples = 0.45 * exp(-behind / 70.0) * pow(max(0.0, cos(behind * 0.2856)), 14.0);
		lines += wcol[i].rgb * w.z * reach * alive * (crest + ripples);
	}

	for (int i = 0; i < glow_n; i++) {
		float u = clamp(1.0 - distance(world, glow[i].xy) / glow[i].z, 0.0, 1.0);
		light += glow[i].w * u * u;
	}

	COLOR = vec4(lines, 1.0 - clamp(light, 0.0, 1.0));
}
