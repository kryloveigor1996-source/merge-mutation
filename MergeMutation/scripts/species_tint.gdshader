shader_type canvas_item;
uniform vec4 target_color : source_color = vec4(1.0);
uniform float strength : hint_range(0.0,1.0) = 0.0;
void fragment() {
	vec4 source = COLOR;
	float high = max(source.r,max(source.g,source.b));
	float low = min(source.r,min(source.g,source.b));
	// Select saturated purple fur. Preserve highlights, dark outlines, eyes and wings.
	float mask = smoothstep(0.10,0.35,high-low) * smoothstep(0.08,0.26,high);
	mask *= smoothstep(-0.02,0.12,source.b-source.g) * smoothstep(-0.03,0.10,source.r-source.g);
	vec3 tinted = target_color.rgb * (high/max(max(target_color.r,target_color.g),target_color.b));
	COLOR = vec4(mix(source.rgb,tinted,mask*strength),source.a);
}
