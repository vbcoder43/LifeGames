extends Node2D
# TODO: Create a rendering device function wrapper
var rd : RenderingDevice
var shader : RID
var uniform_set : RID
var pipeline : RID

var texture_0 : RID
var texture_1 : RID
var texture_kernel : RID
var push_constants : PackedByteArray

var paused := true
var time : float
var store_on_texture_1 := false
const GRID_SIZE : int = 512
var step_size : float = 0.15
var kernel_radius : float = 45.0
var kernel_sigma : float = 300.0
var growth_sigma : float = 0.23
var growth_mean : float = 0.26
@onready var sim_window : Sprite2D = $SimWindow
@onready var kernel_window : Sprite2D = $KernelWindow
var test_pattern : Texture2D = load("res://lenia_test512.png")

func _ready():
	init_rd()

func _process(delta):
	DisplayServer.window_set_title(str(delta*1000.0)+" ms, "+str(1/delta)+" fps")
	$UI/lblFPS.text = "FPS: "+str(Engine.get_frames_per_second())+" |||| "+str(1/Engine.get_frames_per_second()*1000)+" ms"
	if Input.is_action_just_pressed("ui_accept"):
		paused = false
	if Input.is_action_just_pressed("ui_cancel"):
		paused = true
	if !paused:
		if(store_on_texture_1):
			(sim_window.texture as Texture2DRD).texture_rd_rid = texture_1
		else:
			(sim_window.texture as Texture2DRD).texture_rd_rid = texture_0
		process_rd()
		store_on_texture_1 = store_on_texture_1 != true #xor to toggle between buffers
		update_rd(delta)

func init_rd():
	rd = RenderingServer.get_rendering_device()
	shader = rd.shader_create_from_spirv(load("res://Lenia/Lenia.glsl").get_spirv())
	pipeline = rd.compute_pipeline_create(shader)
	
	var image : Image = test_pattern.get_image()
	image.convert(Image.FORMAT_RGBAF)
	var texfmt := RDTextureFormat.new()
	texfmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	texfmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	texfmt.width = GRID_SIZE
	texfmt.height = GRID_SIZE
	texfmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT \
					| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT \
					| RenderingDevice.TEXTURE_USAGE_STORAGE_BIT \
					| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	texture_0 = rd.texture_create(texfmt, RDTextureView.new(), [image.get_data()])
	texture_1 = rd.texture_create(texfmt, RDTextureView.new(), [image.get_data()])
	texture_kernel = rd.texture_create(texfmt, RDTextureView.new(), [])
	(sim_window.texture as Texture2DRD).texture_rd_rid = texture_1
	(kernel_window.texture as Texture2DRD).texture_rd_rid = texture_kernel 
	
	push_constants = PackedFloat32Array([time,
				store_on_texture_1,
				GRID_SIZE,
				step_size,
				kernel_radius,
				kernel_sigma,
				growth_sigma,
				growth_mean]).to_byte_array()
	
	var uniform_texture_0 := RDUniform.new()
	uniform_texture_0.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_texture_0.binding = 0
	uniform_texture_0.add_id(texture_0)
	var uniform_texture_1 := RDUniform.new()
	uniform_texture_1.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_texture_1.binding = 1
	uniform_texture_1.add_id(texture_1)
	var uniform_texture_kernel := RDUniform.new()
	uniform_texture_kernel.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_texture_kernel.binding = 2
	uniform_texture_kernel.add_id(texture_kernel)
	uniform_set = rd.uniform_set_create([uniform_texture_0,
										uniform_texture_1,
										uniform_texture_kernel],
										shader, 0)

func process_rd():
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constants, push_constants.size())
	rd.compute_list_dispatch(compute_list, GRID_SIZE/8, GRID_SIZE/8, 1)
	rd.compute_list_end()
	# not needed in godot 4.4?
	#rd.submit()
	#rd.sync()

func update_rd(delta):
	time += delta
	push_constants = PackedFloat32Array([time,
				store_on_texture_1,
				GRID_SIZE,
				step_size,
				kernel_radius,
				kernel_sigma,
				growth_sigma,
				growth_mean]).to_byte_array()
