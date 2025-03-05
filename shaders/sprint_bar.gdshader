shader_type canvas_item;

// Uniforms controlling the grid and dot appearance (in UV units)
uniform float cell_size = 0.1;         // Spacing between grid cells
uniform float min_dot_radius = 0.01;    // Minimum dot radius (for darker areas)
uniform float max_dot_radius = 0.03;    // Maximum dot radius (for brighter areas)
uniform float edge_smoothness = 0.001;  // Controls anti-aliasing at the dot edge

void fragment() {
    // Determine the center of the current grid cell
    vec2 cell = vec2(cell_size);
    vec2 grid_uv = floor(UV / cell) * cell + cell * 0.5;
    
    // Compute the distance from the fragment to the cell center
    float dist = distance(UV, grid_uv);
    
    // Sample the original texture at the grid cell’s center
    vec4 sample_color = texture(TEXTURE, grid_uv);
    // Convert the sample color to a brightness value using luminance
    float brightness = dot(sample_color.rgb, vec3(0.299, 0.587, 0.114));
    
    // Map brightness to a dot radius: brighter areas yield larger dots
    float dot_radius = mix(min_dot_radius, max_dot_radius, brightness);
    
    // Use smoothstep to create an anti-aliased edge for the dot
    float alpha = 1.0 - smoothstep(dot_radius, dot_radius + edge_smoothness, dist);
    
    // Render the dot in green (background will be black)
    COLOR = vec4(0.0, 1.0, 0.0, alpha);
}
