// Manga Shader for Godot (MIT)
// Made by Joy-less: https://github.com/Joy-less/MangaShader
// Inspired by Exuin: https://godotshaders.com/shader/screentone-black-spaced-pixels
// Modified for inventory slot icons

shader_type canvas_item;

uniform bool enabled = true;
uniform bool inverted = false;
uniform bool grayscale = false;
uniform float strength = 0.5; // Strength of the overlay effect
uniform float light = 1.0; // Brightness of light pixels
uniform float dark = 0.5; // Brightness of dark pixels
uniform float dot_spread = 17.0; // Distance between dots
uniform float dot_size = 1.0; // Size of each dot
uniform vec4 tint_color : source_color = vec4(0.2, 1.0, 0.0, 1.0); // #33FF00 in normalized RGB

bool is_light_pixel(float average, ivec2 pixel_pos) {
	int max_i = int(average * dot_spread);

	return (((pixel_pos.x) % 4 == 0 && (pixel_pos.y + 3) % 4 == 0)
		|| (max_i > 1 && (pixel_pos.x + 2) % 4 == 0 && (pixel_pos.y + 1) % 4 == 0)
		|| (max_i > 2 && (pixel_pos.x + 2) % 4 == 0 && (pixel_pos.y + 3) % 4 == 0)
		|| (max_i > 3 && (pixel_pos.x) % 4 == 0 && (pixel_pos.y + 1) % 4 == 0)
		|| (max_i > 4 && (pixel_pos.x + 1) % 4 == 0 && (pixel_pos.y + 2) % 4 == 0)
		|| (max_i > 5 && (pixel_pos.x + 3) % 4 == 0 && (pixel_pos.y) % 4 == 0)
		|| (max_i > 6 && (pixel_pos.x + 3) % 4 == 0 && (pixel_pos.y + 2) % 4 == 0)
		|| (max_i > 7 && (pixel_pos.x + 1) % 4 == 0 && (pixel_pos.y) % 4 == 0)
		|| (max_i > 8 && (pixel_pos.x + 1) % 4 == 0 && (pixel_pos.y + 3) % 4 == 0)
		|| (max_i > 9 && (pixel_pos.x + 3) % 4 == 0 && (pixel_pos.y + 1) % 4 == 0)
		|| (max_i > 10 && (pixel_pos.x + 3) % 4 == 0 && (pixel_pos.y + 3) % 4 == 0)
		|| (max_i > 11 && (pixel_pos.x + 1) % 4 == 0 && (pixel_pos.y + 1) % 4 == 0)
		|| (max_i > 12 && (pixel_pos.x) % 4 == 0 && (pixel_pos.y + 2) % 4 == 0)
		|| (max_i > 13 && (pixel_pos.x + 2) % 4 == 0 && (pixel_pos.y) % 4 == 0)
		|| (max_i > 14 && (pixel_pos.x + 2) % 4 == 0 && (pixel_pos.y + 2) % 4 == 0)
		|| (max_i > 15));
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec4 final_color = tex_color;
	
	if (enabled) {
		vec2 texture_size = vec2(textureSize(TEXTURE, 0));
		vec2 pixel_pos = floor(UV * texture_size / dot_size);
		float color_average = (tex_color.r + tex_color.g + tex_color.b) / 3.0;
		
		// Apply manga effect
		vec3 manga_color = is_light_pixel(color_average, ivec2(pixel_pos)) 
			? vec3(light) 
			: vec3(dark);
		
		if (inverted) {
			manga_color = vec3(1) - manga_color;
		}
		
		// Mix original color with manga effect
		vec3 effect_color = mix(tex_color.rgb, manga_color, strength);
		final_color = vec4(effect_color, tex_color.a);
	}
	
	// Apply green tint to ALL slots (works for both empty and filled)
	final_color = mix(final_color, tint_color, strength);
	
	// Force full tint for transparent areas (empty slots)
	if (tex_color.a < 0.1) {
		final_color = tint_color;
	}
	
	// Preserve original alpha for transparency
	final_color.a = tex_color.a;
	
	COLOR = final_color;
}