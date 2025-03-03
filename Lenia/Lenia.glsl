#[compute]
#version 450
#define PI 3.14159265358979323846f

// Keep data in alpha channel and color code states in rgb

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) restrict uniform image2D TEXTURE_0;
layout(set = 0, binding = 1, rgba32f) restrict uniform image2D TEXTURE_1;
layout(set = 0, binding = 2, rgba32f) restrict uniform image2D TEXTURE_KERNEL;
// layout(set = 0, binding = 3, rgba32f) restrict uniform image2D TEXTURE_FFT;

// layout(set = 1, binding = 0, std430) restrict buffer _kernel {
// 	float size;
// 	float data[];
// } kernel;

layout(push_constant, std430) restrict uniform _params {
	float TIME;
	float store_on_texture_1;
	float grid_size;
	float step_size;
	float kernel_radius;
	float kernel_sigma;
	float growth_sigma;
	float growth_mean;
} params;

float gaussian2d(vec2 pos, float sigma, float mu);
float growth(float val);

void main() {
	float sum = 0.0;
	float kernel_sum = 0.0;
	for (int x = -int(params.kernel_radius); x <= int(params.kernel_radius); ++x) {
		for (int y = -int(params.kernel_radius); y <= int(params.kernel_radius); ++y) {
			// using grid_size to connect edges of the texture
			int nx = int(gl_GlobalInvocationID.x + x + params.grid_size) % int(params.grid_size);
			int ny = int(gl_GlobalInvocationID.y + y + params.grid_size) % int(params.grid_size);
			vec4 temp_col = imageLoad(TEXTURE_1, ivec2(nx, ny));
			if(bool(params.store_on_texture_1)) temp_col = imageLoad(TEXTURE_0, ivec2(nx, ny));
			float gauss = gaussian2d(vec2(x, y), params.kernel_sigma, 0.0) - gaussian2d(vec2(x, y), params.kernel_sigma/3.0, 0.0);
			kernel_sum += gauss;
			sum += temp_col.a * gauss;
		}
	}
	sum /= kernel_sum;

	ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
	vec4 color = imageLoad(TEXTURE_1, texel);
	if(bool(params.store_on_texture_1)) color = imageLoad(TEXTURE_0, texel);
	color = vec4(clamp(growth(sum)+0.4, 0.0, 1.0),
				clamp(growth(sum)+0.4, 0.0, 1.0),
				clamp(1.4-growth(sum), 0.0, 1.0),
				clamp(color.a + growth(sum) * params.step_size, 0.0, 1.0));
	if(bool(params.store_on_texture_1)) imageStore(TEXTURE_1, texel, color);
	else imageStore(TEXTURE_0, texel, color);

	float gauss = gaussian2d(gl_GlobalInvocationID.xy, params.kernel_sigma, params.grid_size/2.0) - gaussian2d(gl_GlobalInvocationID.xy, params.kernel_sigma/3.0, params.grid_size/2.0);
	vec4 kernel_color = vec4(clamp(gauss+0.2, 0.0, 1.0),
							0.0,
							clamp(1.2-gauss, 0.0, 1.0),
							1.0);
	imageStore(TEXTURE_KERNEL, texel, kernel_color);
}

// smooth kernel
float gaussian2d(vec2 pos, float sigma, float mu) {
	//area normalize factor (1.0/sqrt(2.0*PI*sigma*sigma))
	return exp(-(((pos.x-mu)*(pos.x-mu)) + ((pos.y-mu)*(pos.y-mu)))/(2.0*sigma*sigma));
}

float growth(float val) {
	// return float(val>=0.12 && val<=0.15) - float(val<0.12 || val>0.15);
	// Smooth growth
	return gaussian2d(vec2(val, 0.0), params.growth_sigma, params.growth_mean) * 2.0 - 1.0;
}