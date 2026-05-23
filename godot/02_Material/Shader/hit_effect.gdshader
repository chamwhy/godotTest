shader_type canvas_item;

uniform vec4 hit_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 original = texture(TEXTURE, UV);
    // alpha는 원본 유지, RGB만 hit_color로 mix
    COLOR = vec4(mix(original.rgb, hit_color.rgb, intensity * original.a), original.a);
}