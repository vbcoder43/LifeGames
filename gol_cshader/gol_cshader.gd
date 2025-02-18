extends Node2D

var grid_size = 1024
var zoom = 4

var rd : RenderingDevice
var shader : RID
#var input_texture : RID
var output_texture : RID
var push_constants : PackedFloat32Array
var uniform_set : RID
var pipeline : RID

@onready var display : Sprite2D = $display
#untick generate mipmap
@onready var noise : Sprite2D = $noise
var test_pattern_1024 : Texture2D = load("res://goltest1024.png")
var test_pattern_512 : Texture2D = load("res://goltest512.png")

var start := false
var use_noise := true

func _ready():
	init_rd()

func _process(delta):
	DisplayServer.window_set_title(str(delta*1000.0)+" ms, "+str(1/delta)+" fps")
	$UI/Label.text = "FPS: "+str(Engine.get_frames_per_second())+" |||| "+str(delta*1000)+" ms"
	if Input.is_action_just_pressed("ui_accept"):
		start = true
	if Input.is_action_just_pressed("ui_cancel"):
		start = false
	if start:
		process_rd()
		update_rd()

func init_rd():
	#get since we want to work with textures
	rd = RenderingServer.get_rendering_device()
	shader = rd.shader_create_from_spirv(load("res://gol_cshader/gol_cshader.glsl").get_spirv())
	pipeline = rd.compute_pipeline_create(shader)
	
	push_constants = PackedFloat32Array([grid_size, zoom, 0.0, 0.0])
	var texfmt = RDTextureFormat.new()
	texfmt.width = grid_size
	texfmt.height = grid_size
	texfmt.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	texfmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	texfmt.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT \
					| RenderingDevice.TEXTURE_USAGE_STORAGE_BIT \
					| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT \
					| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	var image : Image
	if grid_size == 512:
		image = test_pattern_512.get_image()
	if grid_size == 1024:
		image = test_pattern_1024.get_image()
	if use_noise:
		await noise.texture.changed
		image = noise.texture.get_image()
	image.convert(Image.FORMAT_RGBAF)
	print(image)
	#input_texture = rd.texture_create(texfmt, RDTextureView.new(), [image.get_data()])
	output_texture = rd.texture_create(texfmt, RDTextureView.new(), [image.get_data()])
	(display.texture as Texture2DRD).texture_rd_rid = output_texture
	
	#var input_texture_uniform = RDUniform.new()
	#input_texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	#input_texture_uniform.binding = 1
	#input_texture_uniform.add_id(input_texture)
	var output_texture_uniform = RDUniform.new()
	output_texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output_texture_uniform.binding = 0
	output_texture_uniform.add_id(output_texture)
	#uniform_set = rd.uniform_set_create([output_texture_uniform, input_texture_uniform], shader, 0)
	uniform_set = rd.uniform_set_create([output_texture_uniform], shader, 0)
	
func process_rd():
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constants.to_byte_array(), push_constants.size()*4)
	rd.compute_list_dispatch(compute_list, grid_size/8, grid_size/8, 1)
	rd.compute_list_end()
	rd.submit()
	#no need to sync when not reading data back but since we push constants and submit everyframe we need it
	rd.sync()

func update_rd():
	push_constants = PackedFloat32Array([grid_size, zoom, 0.0, 0.0])
	#rd.texture_update(input_texture, 0, rd.texture_get_data(output_texture, 0))

#fixed the need for 2 buffers (input_texture)
#now we read and then write to same output buffer thanks to lowering invocations
#(it fails to show correct picture with 32 and single buffer to read then write to)
#and using barriers in glsl, barriers only work in a workgroup, not between them.
#also boundary warp doesnt work with single output texture, no clue why
