@tool
extends Node

const MAX_LIGHTS: int = 128

var masks_loaded: bool = false
var registed_lights: Array[FakePointLight2D]
var last_light_data: Array[Dictionary]
var lights_count: int

# BUFFERS
var samplerArray: Texture2DArray
var data_textures: Array[ImageTexture]
var data_images: Array[Image]

var frame_update: float

func _ready() -> void:
	load_array_masks()
	create_buffer()

func load_array_masks() -> void:
	if masks_loaded:
		return
	var mask_0: Image = load("res://mask/lights/glow_pixelated.png").get_image()
	var mask_1: Image = load("res://mask/lights/conical_light.png").get_image()
	var mask_2: Image = load("res://mask/lights/glow_pixelated_divided.png").get_image()
	
	samplerArray = Texture2DArray.new()
	var images: Array[Image] = [
		mask_0,
		mask_1,
		mask_2
	]
	
	samplerArray.create_from_images(images)
	if samplerArray:
		print("Máscaras de luz carregadas com sucesso :D")
		masks_loaded = true
	else:
		printerr("Não foi possível carregar as Máscaras de luz. SsmplerArray: %s" % samplerArray)
	
	RenderingServer.global_shader_parameter_set("light_masks", samplerArray)

func create_buffer() -> void:
	if data_images.size() > 0:
		return
	
	# DATA 0
	data_images.append(Image.create(1, MAX_LIGHTS, true, Image.FORMAT_RGBAH)); data_images[0].fill(Color(0))
	data_textures.append(ImageTexture.create_from_image(data_images[0]))
	
	# DATA 1
	data_images.append(Image.create(1, MAX_LIGHTS, true, Image.FORMAT_RGBAH)); data_images[1].fill(Color(0))
	data_textures.append(ImageTexture.create_from_image(data_images[1]))
	
	# DATA 2
	data_images.append(Image.create(1, MAX_LIGHTS, true, Image.FORMAT_RGBAH)); data_images[2].fill(Color(0))
	data_textures.append(ImageTexture.create_from_image(data_images[2]))
	
	# DATA 3
	data_images.append(Image.create(1, MAX_LIGHTS, true, Image.FORMAT_RGBAH)); data_images[3].fill(Color(0))
	data_textures.append(ImageTexture.create_from_image(data_images[3]))

func register_light(light: FakePointLight2D) -> void:
	if light in registed_lights:
		return
	registed_lights.append(light)
	last_light_data.append({
		"light_pos": light.global_position,
		"light_rotation": light.global_rotation,
		"light_mask_id": light.mask_light_id,
		"mask_scale": light.scale,
		"energy": light.energy,
		"light_color": light.light_color,
		"visible": light.visible
	})
	lights_count = registed_lights.size()
	RenderingServer.global_shader_parameter_set("light_count", lights_count)
	force_update()

func unregister_light(light: FakePointLight2D) -> void:
	if light in registed_lights:
		var idx: int = registed_lights.find(light)
		registed_lights.erase(light)
		if idx != -1:
			last_light_data.remove_at(idx)
	lights_count = registed_lights.size()
	RenderingServer.global_shader_parameter_set("light_count", lights_count)
	
	clear_pixels_buffer(lights_count)
	force_update()

func _process(delta: float) -> void:
	frame_update += delta
	if frame_update >= 0.1:
		frame_update = 0
		update()

func update() -> void:
	var changed: bool = false
	var buffers_need_update: bool = false
	for x in range(MAX_LIGHTS):
		if x < lights_count:
			var light: FakePointLight2D = registed_lights[x]
			var last_data: Dictionary = last_light_data[x]
			changed = (light.mask_light_id != last_data.light_mask_id or light.energy != last_data.energy \
			or light.light_color != last_data.light_color or light.global_position != last_data.light_pos \
			or light.scale != last_data.mask_scale or light.visible != last_data.visible or last_data.light_rotation != light.global_rotation)
			
			if changed:
				last_data.light_mask_id = light.mask_light_id
				last_data.mask_scale = light.scale
				last_data.light_rotation = light.global_rotation
				last_data.energy = light.energy
				last_data.light_color = light.light_color
				last_data.light_pos = light.global_position
				last_data.visible = light.visible
				
				# =========== DATA REC ===========
				
				#light_color & energy
				data_images[0].set_pixel(0, x, Color(light.light_color, light.energy))
				#light_pos
				data_images[1].set_pixel(0, x, Color(light.global_position.x, light.global_position.y, 0))
				#mask_id
				data_images[2].set_pixel(0, x, Color(light.mask_light_id, float(light.visible), 0))
				#transforms
				data_images[3].set_pixel(0, x, Color(sin(light.global_rotation), light.scale.x, light.scale.y, cos(light.global_rotation)))
				
				buffers_need_update = true
				# Update buffers texture
				
			
	if buffers_need_update:
		update_buffers()
	if data_textures.size() > 0:
		RenderingServer.global_shader_parameter_set("light_buffer_0", data_textures[0])
		RenderingServer.global_shader_parameter_set("light_buffer_1", data_textures[1])
		RenderingServer.global_shader_parameter_set("light_buffer_2", data_textures[2])
		RenderingServer.global_shader_parameter_set("light_buffer_3", data_textures[3])

func force_update() -> void:
	RenderingServer.global_shader_parameter_set("light_masks", samplerArray)
	lights_count = registed_lights.size()
	RenderingServer.global_shader_parameter_set("light_count", lights_count)
	var buffers_need_update: bool = false
	for x in range(lights_count):
		if x < lights_count:
			var light: FakePointLight2D = registed_lights[x]
			# =========== DATA REC ===========
				
			#light_color & energy
			data_images[0].set_pixel(0, x, Color(light.light_color, light.energy))
			#light_pos & mask_sacle
			data_images[1].set_pixel(0, x, Color(light.global_position.x, light.global_position.y, 0))
			#mask_id
			data_images[2].set_pixel(0, x, Color(light.mask_light_id, float(light.visible), 0))
			#transforms
			data_images[3].set_pixel(0, x, Color(sin(light.global_rotation), light.scale.x, light.scale.y, cos(light.global_rotation)))
			
			buffers_need_update = true
			# Update buffers texture
				
			
	if buffers_need_update:
		update_buffers()
	if data_textures.size() > 0:
		RenderingServer.global_shader_parameter_set("light_buffer_0", data_textures[0])
		RenderingServer.global_shader_parameter_set("light_buffer_1", data_textures[1])
		RenderingServer.global_shader_parameter_set("light_buffer_2", data_textures[2])
		RenderingServer.global_shader_parameter_set("light_buffer_3", data_textures[3])

func clear_pixels_buffer(start_index: int) -> void:
	for x in range(start_index, MAX_LIGHTS):
		data_images[0].set_pixel(0, x, Color(0))
		data_images[1].set_pixel(0, x, Color(0))
		data_images[2].set_pixel(0, x, Color(0))
		data_images[3].set_pixel(0, x, Color(0))
	update_buffers()

func update_buffers() -> void:
	for i in range(4):
		data_textures[i].update(data_images[i])
