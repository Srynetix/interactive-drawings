shader_type spatial;
render_mode cull_disabled, unshaded;

uniform vec4 color_key : source_color;
uniform sampler2D draw_texture;
uniform float tolerance : hint_range(0.0, 1.0, 0.01);
uniform float crop_left : hint_range(0.0, 1.0, 0.01);
uniform float crop_right : hint_range(0.0, 1.0, 0.01);
uniform float crop_bottom : hint_range(0.0, 1.0, 0.01);
uniform float crop_top : hint_range(0.0, 1.0, 0.01);
uniform float wobblyness : hint_range(0.0, 1.0, 0.01);

void vertex() {
	VERTEX.z += cos(VERTEX.y * 4.0 + TIME / 0.25) / 8.0 * wobblyness;
}

void fragment() {
	vec4 col = texture(draw_texture, UV);
	vec4 d4 = abs(col - color_key);
	float d = max(max(d4.r, d4.g), d4.b);
	if (d < tolerance) {
		discard;
	}

	if (UV.x < crop_left || (1.0 - UV.x) < crop_right) {
		discard;
	}

	if (UV.y < crop_top || (1.0 - UV.y) < crop_bottom) {
		discard;
	}

	ALBEDO = col.rgb;
	ALPHA = col.a;
}