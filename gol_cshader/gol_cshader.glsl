#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(push_constant, std430) uniform _params {
	float grid_size;
	float zoom;
	vec2 reserved;
} params;
layout(set = 0, binding = 0, rgba32f) uniform image2D OUTPUT_TEXTURE;
// layout(set = 0, binding = 1, rgba32f) uniform image2D INPUT_TEXTURE;


void main() {
	int neighbors = 0;
	ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
	// boundary warp doesnt work with single output buffer for some reason, no clue why -_-
	// int nx = int(gl_GlobalInvocationID.x + params.grid_size);
	// int ny = int(gl_GlobalInvocationID.y + params.grid_size);
	// float neighbors_arr[8] = {
	// 	imageLoad(OUTPUT_TEXTURE, ivec2((nx - 1)% int(params.grid_size), (ny - 1)% int(params.grid_size))).r,
	// 	imageLoad(OUTPUT_TEXTURE, ivec2(nx % int(params.grid_size), (ny - 1)% int(params.grid_size))).r,
	// 	imageLoad(OUTPUT_TEXTURE, ivec2((nx + 1)% int(params.grid_size), (ny - 1)% int(params.grid_size))).r,
	// 	imageLoad(OUTPUT_TEXTURE, ivec2((nx - 1)% int(params.grid_size), ny% int(params.grid_size))).r,
	// 	imageLoad(OUTPUT_TEXTURE, ivec2((nx + 1)% int(params.grid_size), ny% int(params.grid_size))).r,
	// 	imageLoad(OUTPUT_TEXTURE, ivec2((nx - 1)% int(params.grid_size), (ny + 1)% int(params.grid_size))).r,
	// 	imageLoad(OUTPUT_TEXTURE, ivec2(nx % int(params.grid_size) , (ny + 1)% int(params.grid_size))).r,
	// 	imageLoad(OUTPUT_TEXTURE, ivec2((nx + 1)% int(params.grid_size), (ny + 1)% int(params.grid_size))).r
	// };
	// no warping
	float neighbors_arr[8] = {
		imageLoad(OUTPUT_TEXTURE, ivec2(gl_GlobalInvocationID.x - 1, gl_GlobalInvocationID.y - 1)).r,
		imageLoad(OUTPUT_TEXTURE, ivec2(gl_GlobalInvocationID.x, gl_GlobalInvocationID.y - 1)).r,
		imageLoad(OUTPUT_TEXTURE, ivec2(gl_GlobalInvocationID.x + 1, gl_GlobalInvocationID.y - 1)).r,
		imageLoad(OUTPUT_TEXTURE, ivec2(gl_GlobalInvocationID.x - 1, gl_GlobalInvocationID.y)).r,
		imageLoad(OUTPUT_TEXTURE, ivec2(gl_GlobalInvocationID.x + 1, gl_GlobalInvocationID.y)).r,
		imageLoad(OUTPUT_TEXTURE, ivec2(gl_GlobalInvocationID.x - 1, gl_GlobalInvocationID.y + 1)).r,
		imageLoad(OUTPUT_TEXTURE, ivec2(gl_GlobalInvocationID.x, gl_GlobalInvocationID.y + 1)).r,
		imageLoad(OUTPUT_TEXTURE, ivec2(gl_GlobalInvocationID.x + 1, gl_GlobalInvocationID.y + 1)).r
	};
	vec4 color = imageLoad(OUTPUT_TEXTURE, texel);
	memoryBarrier();
	barrier();
	for(int i = 0; i<8; ++i) neighbors += int(round(neighbors_arr[i]));
	// loop doesnt work properly with barriers
	// for(int dx = -1; dx <= 1; ++dx) {
	// 	for(int dy = -1; dy <= 1; ++dy) {
	// 		if(dx==0 && dy==0) continue;
	// 		int nx = int(gl_GlobalInvocationID.x + dx + params.grid_size) % int(params.grid_size);
	// 		int ny = int(gl_GlobalInvocationID.y + dy + params.grid_size) % int(params.grid_size);
	// 		ivec2 dtexel = ivec2(nx, ny);
	// 		vec4 col = imageLoad(INPUT_TEXTURE, dtexel);
	// 		neighbors += int(round(col.r));
	// 	}
	// } 
	if(color.r > 0.5) color.rgb = (neighbors==2 || neighbors==3) ? vec3(1.0, neighbors/4.0, neighbors/4.0) : vec3(0.0, neighbors/4.0, neighbors/4.0);
	else color.rgb = (neighbors==3) ? vec3(1.0, neighbors/4.0, neighbors/4.0) : vec3(0.0, neighbors/4.0, neighbors/4.0);
	imageStore(OUTPUT_TEXTURE, texel, color);
}