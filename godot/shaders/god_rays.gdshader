// Shafts of light falling through the trees, shimmering slowly. Put it on a ColorRect over the scene.
// Based on "God Rays shader - inspired by pend00" from godotshaders.com (CC0). Changed for phones: it adds
// light on top (blend_add) instead of reading the screen back, which is much cheaper.
shader_type canvas_item;
render_mode blend_add;

uniform float ray_angle = -0.3;
uniform float ray_position = -0.2;
uniform float spread : hint_range(0.0, 1.0) = 0.5;
uniform float cutoff : hint_range(-1.0, 1.0) = 0.1;
uniform float falloff : hint_range(0.0, 1.0) = 0.2;
uniform float edge_fade : hint_range(0.0, 1.0) = 0.15;
uniform float speed = 1.0;
uniform float ray1_density = 8.0;
uniform float ray2_density = 30.0;
uniform float ray2_intensity : hint_range(0.0, 1.0) = 0.3;
uniform vec4 color : source_color = vec4(1.0, 0.9, 0.65, 0.35);
uniform float seed = 5.0;

float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	float a = random(i);
	float b = random(i + vec2(1.0, 0.0));
	float c = random(i + vec2(0.0, 1.0));
	float d = random(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec2 centered_uv = UV - vec2(0.5, ray_position);
	float s = sin(ray_angle);
	float c = cos(ray_angle);
	vec2 t = mat2(vec2(c, -s), vec2(s, c)) * centered_uv;
	t.y = t.y / (t.y * spread + 1.0);
	t += vec2(0.5);

	float time_factor = TIME * speed;
	vec2 ray1_uv = vec2(t.x * ray1_density + sin(time_factor * 0.1) * (ray1_density * 0.2) + seed, t.y);
	vec2 ray2_uv = vec2(t.x * ray2_density + sin(time_factor * 0.2) * (ray1_density * 0.2) + seed, t.y);
	float cut_x = smoothstep(cutoff - 0.1, cutoff + 0.1, t.x) * smoothstep(1.0 + cutoff + 0.1, 1.0 + cutoff - 0.1, t.x);

	float rays = clamp(noise(ray1_uv) + noise(ray2_uv) * ray2_intensity, 0.0, 1.0);
	rays *= cut_x;
	rays *= smoothstep(0.0, falloff, 1.0 - UV.y);
	rays *= smoothstep(0.0, edge_fade, t.x);
	rays *= smoothstep(0.0, edge_fade, 1.0 - t.x);
	COLOR = vec4(color.rgb * rays * color.a, 1.0);
}
