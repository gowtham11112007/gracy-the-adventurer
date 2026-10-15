shader_type canvas_item;
// Black everywhere except a circle of `radius` pixels around `center` (both in screen pixels).
uniform vec2 center = vec2(640.0, 360.0);
uniform float radius = 4000.0;

void fragment() {
	float d = distance(FRAGCOORD.xy, center);
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(radius - 2.0, radius + 2.0, d));
}
