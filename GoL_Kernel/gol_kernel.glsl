#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1)in;
layout(set = 0, binding = 0, rgba32f) uniform image2D texture0;
layout(set = 0, binding = 1, rgba32f) uniform image2D texture1;
layout(push_constant, std430) uniform _params {
	float store_on_texture1;
	float grid_size;
	vec2 reserved1;
} params;

void main() {
	int neighbors = 0;
	for(int dx = -1; dx <= 1; ++dx) {
		for(int dy = -1; dy <= 1; ++dy) {
			if(dx==0 && dy==0) continue;
			int nx = int(gl_GlobalInvocationID.x + dx + params.grid_size) % int(params.grid_size);
			int ny = int(gl_GlobalInvocationID.y + dy + params.grid_size) % int(params.grid_size);
			ivec2 dtexel = ivec2(nx, ny);
			vec4 col = imageLoad(texture1, dtexel);
			if(bool(params.store_on_texture1)) col = imageLoad(texture0, dtexel);
			neighbors += int(round(col.r));
		}
	}
	ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
	vec4 color = imageLoad(texture1, texel);
	if(bool(params.store_on_texture1)) color = imageLoad(texture0, texel);
	if(color.r > 0.5) color.rgb = (neighbors==2 || neighbors==3) ? vec3(1.0, gl_GlobalInvocationID.x/1024.0, gl_GlobalInvocationID.y/1024.0) : vec3(0.0);
	else color.rgb = (neighbors==3) ? vec3(1.0, gl_GlobalInvocationID.x/1024.0, gl_GlobalInvocationID.y/1024.0) : vec3(0.0);
	if(bool(params.store_on_texture1)) imageStore(texture1, texel, color);
	else imageStore(texture0, texel, color);
}