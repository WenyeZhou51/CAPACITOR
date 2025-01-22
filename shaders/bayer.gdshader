shader_type spatial;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform int levels = 8;
uniform float brightness = 1.5;
uniform float gamma = 1;
uniform float posterization_strength = 0.8;
uniform float dark_preservation = 0.05;
uniform float highlight_preservation = 0.1;  // Increased default

void vertex() {
    POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec3 screen_color = texture(SCREEN_TEXTURE, uv).rgb;
    
    // Apply gamma correction
    screen_color = pow(screen_color, vec3(gamma));
    
    // Apply brightness with smoother rolloff for bright areas
    screen_color *= brightness;
    screen_color = 1.0 - (1.0 / (screen_color + 1.0));  // Smooth compression of bright values
    
    // Modified posterization that's more subtle in bright areas
    vec3 posterized = floor(screen_color * float(levels) + 0.5) / float(max(levels - 1, 1));
    
    float luminance = dot(screen_color, vec3(0.299, 0.587, 0.114));
    
    // Modified dark preservation with wider transition
    float darkFactor = smoothstep(dark_preservation, dark_preservation + 0.1, luminance);
    
    // Modified highlight preservation with wider transition and stronger effect
    float highlightFactor = smoothstep(1.0 - highlight_preservation, 1.0 - highlight_preservation * 0.5, luminance);
    highlightFactor = pow(highlightFactor, 2.0);  // Stronger falloff in bright areas
    
    float midFactor = darkFactor * (1.0 - highlightFactor);
    
    // Additional brightness-based adjustment
    float brightnessFactor = 1.0 - smoothstep(0.7, 0.9, luminance);  // Reduce posterization in bright areas
    float finalPosterizeFactor = posterization_strength * midFactor * brightnessFactor;
    
    vec3 final_color = mix(screen_color, posterized, finalPosterizeFactor);
    final_color = pow(final_color, vec3(1.0 / gamma));
    
    ALBEDO = final_color;
}