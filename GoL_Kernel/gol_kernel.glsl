#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
// Use restrict when possible
layout(set = 0, binding = 0, rgba32f) restrict uniform image2D texture0;
layout(set = 0, binding = 1, rgba32f) restrict uniform image2D texture1;
// Shader Storage Buffer Object (SSBO) can have variable sized array, upto 128MB
// https://www.khronos.org/opengl/wiki/Shader_Storage_Buffer_Object (SSBO and UBO)
layout(set = 0, binding = 2, std430) restrict buffer _kernel {
	int size;
	float array[];
} kernel;
layout(push_constant, std430) uniform _params {
	float store_on_texture1;
	float grid_size;
	vec2 reserved1;
} params;

float growth(float current_cell) {
	return 0.0;
}

void main() {
	float sum = 0;
	for (int x = 0; x < int(kernel.size); ++x) {
		for (int y = 0; y < int(kernel.size); ++y) {
			int i = x * int(kernel.size) + y;
			// using grid_size to connect edges of the texture
			int nx = int(gl_GlobalInvocationID.x - (kernel.size/2) + x + params.grid_size) % int(params.grid_size);
			int ny = int(gl_GlobalInvocationID.y - (kernel.size/2) + y + params.grid_size) % int(params.grid_size);
			vec4 temp_col = imageLoad(texture1, ivec2(nx, ny));
			if(bool(params.store_on_texture1)) temp_col = imageLoad(texture0, ivec2(nx, ny));
			sum += temp_col.r * kernel.array[i];
		}
	}
	ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
	vec4 color = imageLoad(texture1, texel);
	if(bool(params.store_on_texture1)) color = imageLoad(texture0, texel);
	if(color.r >= 0.5) color.rgb = (sum>=2 && sum<=3) ? vec3(1.0, gl_GlobalInvocationID.x/1024.0, gl_GlobalInvocationID.y/1024.0) : vec3(0.0);
	else color.rgb = (sum>=2.9 && sum<=3.1) ? vec3(1.0, gl_GlobalInvocationID.x/1024.0, gl_GlobalInvocationID.y/1024.0) : vec3(0.0);
	if(bool(params.store_on_texture1)) imageStore(texture1, texel, color);
	else imageStore(texture0, texel, color);
}