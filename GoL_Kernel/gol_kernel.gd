extends Node2D
# Alternate between two buffers and sync RID with Sprite2D to get both accurate
# and fast results. rather than using a single buffer (wrong simulation and some limitations)
# or two buffers with texture copy on CPU.
# set active buffer in push constant and set the RID in process loop
# single buffer that was used was pretty accurate even with boundary warping but sometimes things would vanish
# this method doesnt seem to have any problem
var rd : RenderingDevice
var shader : RID
var texture0 : RID
var texture1 : RID
var kernel : RID
var push_constants : PackedFloat32Array
var uniform_set : RID
var pipeline : RID

@onready var simwindow : Sprite2D = $simwindow
const SIZE = 1024
var test_pattern_1024 : Texture2D = load("res://goltest1024.png")
var store_on_texture1 := false
var paused := true
var kernel_data : PackedFloat32Array
var kernel_size : int

func _ready():
	init_rd()
	
func _process(delta):
	DisplayServer.window_set_title(str(delta*1000.0)+" ms, "+str(1/delta)+" fps")
	$UI/lblFPS.text = "FPS: "+str(Engine.get_frames_per_second())+" |||| "+str(delta*1000)+" ms"
	if Input.is_action_just_pressed("ui_accept"):
		paused = false
	if Input.is_action_just_pressed("ui_cancel"):
		paused = true
	if !paused:
		if(store_on_texture1):
			(simwindow.texture as Texture2DRD).texture_rd_rid = texture1
		else:
			(simwindow.texture as Texture2DRD).texture_rd_rid = texture0
		process_rd()
		store_on_texture1 = store_on_texture1 != true #xor to toggle between buffers
		update_rd()

func init_rd():
	rd = RenderingServer.get_rendering_device()
	shader = rd.shader_create_from_spirv(load("res://GoL_Kernel/gol_kernel.glsl").get_spirv())
	pipeline = rd.compute_pipeline_create(shader)
	
	var image : Image = test_pattern_1024.get_image()
	image.convert(Image.FORMAT_RGBAF)
	var texfmt := RDTextureFormat.new()
	texfmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	texfmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	texfmt.width = SIZE
	texfmt.height = SIZE
	texfmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT \
					| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT \
					| RenderingDevice.TEXTURE_USAGE_STORAGE_BIT \
					| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	texture0 = rd.texture_create(texfmt, RDTextureView.new(), [image.get_data()])
	texture1 = rd.texture_create(texfmt, RDTextureView.new(), [image.get_data()])
	(simwindow.texture as Texture2DRD).texture_rd_rid = texture1
	init_kernel()
	push_constants = PackedFloat32Array([store_on_texture1, SIZE, 0.0, 0.0])
	
	var uniform_texture0 := RDUniform.new()
	uniform_texture0.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_texture0.binding = 0
	uniform_texture0.add_id(texture0)
	var uniform_texture1 := RDUniform.new()
	uniform_texture1.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_texture1.binding = 1
	uniform_texture1.add_id(texture1)
	var uniform_kernel := RDUniform.new()
	uniform_kernel.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_kernel.binding = 2
	uniform_kernel.add_id(kernel)
	uniform_set = rd.uniform_set_create([uniform_texture0,
										uniform_texture1,
										uniform_kernel],
										shader, 0)
	
func process_rd():
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constants.to_byte_array(), push_constants.size()*4)
	rd.compute_list_dispatch(compute_list, SIZE/8, SIZE/8, 1)
	rd.compute_list_end()
	rd.submit()
	# sync is needed cuz we switch between texture buffers
	rd.sync()

func update_rd():
	push_constants = PackedFloat32Array([store_on_texture1, SIZE, 0.0, 0.0])

func init_kernel():
	kernel_data = PackedFloat32Array([
	1.0, 1.0, 1.0,
	1.0, 0.0, 1.0,
	1.0, 1.0, 1.0
	])
	kernel_size = int(sqrt(kernel_data.size()))
	var temp_array := PackedInt32Array([kernel_size]).to_byte_array()
	temp_array.append_array(kernel_data.to_byte_array())
	kernel = rd.storage_buffer_create(temp_array.size(), temp_array)
