shader_type spatial;

uniform vec4 water_color : source_color = vec4(0.0, 0.8, 1.0, 0.6);
uniform vec4 fresnel_color : source_color = vec4(0.8, 0.9, 1.0, 0.8);
uniform float wave_speed : hint_range(0.0, 1.0, 0.1) = 0.1;
uniform float wave_strength : hint_range(0.0, 1.0, 0.1) = 0.1;
uniform float fresnel_power : hint_range(1.0, 10.0, 0.1) = 3.0;

void fragment() {
    // Simple wave movement based on time
    vec2 time_offset = vec2(TIME * wave_speed);
    float wave = sin(UV.x * 10.0 + time_offset.x) * cos(UV.y * 10.0 + time_offset.y) * wave_strength;
    
    // Calculate fresnel effect
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);
    
    // Mix water color with fresnel effect
    vec4 final_color = mix(water_color, fresnel_color, fresnel);
    
    // Apply wave displacement to alpha
    final_color.a = water_color.a * (1.0 + wave);
    
    ALBEDO = final_color.rgb;
    ALPHA = final_color.a;
    METALLIC = 0.3;
    ROUGHNESS = 0.1;
    SPECULAR = 0.5;
}

void vertex() {
    // Optional: Add slight vertex displacement for waves
    VERTEX.y += sin(VERTEX.x * 2.0 + TIME * wave_speed) * cos(VERTEX.z * 2.0 + TIME * wave_speed) * wave_strength;
}