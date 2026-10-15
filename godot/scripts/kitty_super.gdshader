shader_type canvas_item;
// Super Kitty: her own picture in shining silver-gray (grayscale, a little brighter).
// COLOR already holds her picture's colour here, so it is replaced, not multiplied.
void fragment() {
	vec4 c = COLOR;
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(min(g * 1.25, 1.0)), c.a);
}
