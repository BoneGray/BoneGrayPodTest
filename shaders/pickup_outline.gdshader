shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.86, 0.92, 1.0, 1.0);
uniform float outline_size : hint_range(0.0, 4.0, 0.25) = 1.0;

void fragment() {
	vec4 base_color = texture(TEXTURE, UV);
	COLOR = vec4(outline_color.rgb, outline_color.a * base_color.a);
}
