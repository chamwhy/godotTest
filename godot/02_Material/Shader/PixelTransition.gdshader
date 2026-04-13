// PixelTransition.gdshader
shader_type canvas_item;

uniform float pixel_size : hint_range(1.0, 128.0) = 1.0;
uniform float fade_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    // 픽셀화: UV를 pixel_size 단위로 스냅
    vec2 uv = SCREEN_UV;
    vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 cell_size = pixel_size / screen_size;
    vec2 snapped = (floor(uv / cell_size) + 0.5) * cell_size;
    
    vec4 pixel_color = texture(SCREEN_TEXTURE, snapped);
    
    // 검정으로 fade
    vec4 final_color = mix(pixel_color, vec4(0.0, 0.0, 0.0, 1.0), fade_amount);
    
    COLOR = final_color;
}