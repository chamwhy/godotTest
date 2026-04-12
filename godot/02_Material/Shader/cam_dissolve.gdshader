shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float pixel_size = 32.0;

void fragment() {
    // Get the screen UV and snap it to the pixel grid
    vec2 grid_uv = floor(UV * pixel_size) / pixel_size;
    
    // Create a simple circular mask based on the distance from the center
    // You can also use a texture here for more complex patterns
    float dist = distance(grid_uv, vec2(0.5));
    
    // Compare distance to progress to create the "reveal" effect
    if (dist < progress * 1.5) {
        discard; // Make the pixel transparent
    }
    
    COLOR = vec4(0.0, 0.0, 0.0, 1.0); // The transition color (Black)
}