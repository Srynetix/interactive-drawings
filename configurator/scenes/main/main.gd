extends Control

@onready var pick_btn := %PickButton as Button
@onready var send_btn := %SendButton as Button
@onready var file_dialog := %FileDialog as FileDialog
@onready var preview1 := %Preview1 as ColorRect
@onready var preview2 := %Preview2 as ColorRect
@onready var connect_btn := %ConnectButton as Button
@onready var connect_label := %ConnectLabel as Label
@onready var server_address := %ServerAddress as LineEdit
@onready var preset_selector := %PresetSelector as OptionButton
@onready var drawing_name := %DrawingName as LineEdit
@onready var local_store_btn := %LocalStoreButton as Button

@onready var toggle_parameters_btn_1 := %ToggleParameters as Button
@onready var toggle_parameters_btn_2 := %ToggleParameters2 as Button
@onready var parameters_1 := %Parameters1 as Control
@onready var parameters_2 := %Parameters2 as Control

@onready var color_key := %ColorKey as ColorPickerButton
@onready var tolerance := %Tolerance as HSlider
@onready var crop_left := %CropLeft as HSlider
@onready var crop_right := %CropRight as HSlider
@onready var crop_top := %CropTop as HSlider
@onready var crop_bottom := %CropBottom as HSlider

@onready var color_key_2 := %ColorKey2 as ColorPickerButton
@onready var tolerance_2 := %Tolerance2 as HSlider
@onready var crop_left_2 := %CropLeft2 as HSlider
@onready var crop_right_2 := %CropRight2 as HSlider
@onready var crop_top_2 := %CropTop2 as HSlider
@onready var crop_bottom_2 := %CropBottom2 as HSlider

@onready var fish_kind := %FishKind as CheckBox
@onready var frog_kind := %FrogKind as CheckBox
@onready var bee_kind := %BeeKind as CheckBox

@onready var shader1 := preview1.material as ShaderMaterial
@onready var shader2 := preview2.material as ShaderMaterial
@onready var remote_drawing_line_template := %RemoteDrawingLineTemplate as HBoxContainer
@onready var local_drawing_line_template := %LocalDrawingLineTemplate as HBoxContainer
@onready var refresh_remote_drawings := %RefreshRemoteDrawings as Button

@onready var camera_focus_time := %CameraFocusTime as SpinBox
@onready var camera_z_distance := %CameraZDistance as SpinBox
@onready var camera_y_distance := %CameraYDistance as SpinBox
@onready var push_config_btn := %PushConfig as Button
@onready var pull_config_btn := %PullConfig as Button

var _drawing_data: Array[Dictionary] = []
var _drawing_data_index: Dictionary = {}

var _local_drawing_data: Array[Dictionary] = []
var _local_drawing_data_index: Dictionary = {}
var _local_drawing_data_lines: Dictionary = {}

var _client: WebSocketClient = WebSocketClient.new()

var _image: Image = null


func _ready() -> void:
	OS.request_permissions()
	add_child(_client)

	send_btn.disabled = true
	pull_config_btn.disabled = true
	push_config_btn.disabled = true
	refresh_remote_drawings.disabled = true

	_client.connected_to_server.connect(func():
		connect_label.text = "Connected."
		send_btn.disabled = false
		pull_config_btn.disabled = false
		push_config_btn.disabled = false
		refresh_remote_drawings.disabled = false
	)

	_client.connection_closed.connect(func():
		connect_label.text = "Disconnected."
		connect_btn.disabled = false
		send_btn.disabled = true
		pull_config_btn.disabled = true
		push_config_btn.disabled = true
		refresh_remote_drawings.disabled = true
	)

	refresh_remote_drawings.pressed.connect(func():
		_client.send(JSON.stringify({
			"kind": "get-drawings"
		}))
	)

	local_store_btn.pressed.connect(func():
		# Persist to disk
		_create_or_update_current_local_drawing()
	)

	pull_config_btn.pressed.connect(func():
		_send_json_to_server({
			"kind": "get-config"
		})
	)

	push_config_btn.pressed.connect(func():
		_send_json_to_server({
			"kind": "set-config",
			"camera_focus_time": camera_focus_time.value,
			"camera_z_distance": camera_z_distance.value,
			"camera_y_distance": camera_y_distance.value,
		})
	)

	remote_drawing_line_template.visible = false
	local_drawing_line_template.visible = false

	_client.message_received.connect(func(msg):
		print("Message received from server: %s" % msg)
		var json_data := JSON.parse_string(msg) as Dictionary
		var kind := json_data["kind"] as String
		if kind == "get-drawings-response":
			# Clear all siblings
			for data in _drawing_data:
				data["line"].queue_free()
			_drawing_data.clear()
			_drawing_data_index.clear()

			var drawings := json_data["drawings"] as Array
			for drawing in drawings:
				var entry := remote_drawing_line_template.duplicate()
				entry.visible = true

				entry.get_node("DrawingNameLabel").text = drawing["name"]
				entry.get_node("DrawingLoadButton").pressed.connect(func():
					print("Set current conf as drawing")
					_update_configuration_from_drawing(drawing)
				)
				entry.get_node("DrawingFocusButton").pressed.connect(func():
					print("Focusing drawing")
					_client.send(JSON.stringify({
						"kind": "focus-drawing",
						"name": drawing["name"]
					}))
				)
				entry.get_node("DrawingDeleteButton").pressed.connect(func():
					print("Deleting drawing")
					_client.send(JSON.stringify({
						"kind": "delete-drawing",
						"name": drawing["name"]
					}))
				)

				var parent := remote_drawing_line_template.get_parent()
				parent.add_child(entry)

				var drawing_d := {
					"data": drawing,
					"line": entry
				}

				_drawing_data.push_back(drawing_d)
				_drawing_data_index[drawing["name"]] = drawing_d

		elif kind == "get-config-response":
			camera_focus_time.value = json_data["camera_focus_time"]
			camera_z_distance.value = json_data["camera_z_distance"]
			camera_y_distance.value = json_data["camera_y_distance"]

	)

	file_dialog.root_subfolder = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	file_dialog.file_selected.connect(func(file):
		print("opening %s" % file)
		_load_image_from_path(file)
	)

	pick_btn.pressed.connect(func():
		file_dialog.popup_centered(get_viewport_rect().size - Vector2(64, 64))
	)

	connect_btn.pressed.connect(func():
		var err = _client.connect_to_url("ws://%s" % server_address.text)
		if err != OK:
			connect_label.text = "Error: %s" % error_string(err)
		else:
			connect_label.text = "Connecting..."
			connect_btn.disabled = true
	)

	send_btn.pressed.connect(func():
		var dump := _prepare_dump()
		_submit_drawing(dump)
	)

	# color_key.color_changed.connect(func(color):
	# 	shader1.set_shader_parameter("color_key", color)
	# )

	# color_key_2.color_changed.connect(func(color):
	# 	shader2.set_shader_parameter("color_key", color)
	# )

	toggle_parameters_btn_1.pressed.connect(func():
		parameters_1.visible = !parameters_1.visible
	)

	toggle_parameters_btn_2.pressed.connect(func():
		parameters_2.visible = !parameters_2.visible
	)

	_map_slider(shader1, tolerance, "tolerance")
	_map_slider(shader1, crop_left, "crop_left")
	_map_slider(shader1, crop_right, "crop_right")
	_map_slider(shader1, crop_bottom, "crop_bottom")
	_map_slider(shader1, crop_top, "crop_top")

	_map_slider(shader2, tolerance_2, "tolerance")
	_map_slider(shader2, crop_left_2, "crop_left")
	_map_slider(shader2, crop_right_2, "crop_right")
	_map_slider(shader2, crop_bottom_2, "crop_bottom")
	_map_slider(shader2, crop_top_2, "crop_top")

	preset_selector.item_selected.connect(func(selected_idx):
		if selected_idx != 0:
			tolerance.value = 0.01
			crop_bottom.value = 0.2
			crop_top.value = 0.2
			crop_left.value = 0.1
			crop_right.value = 0.1

			tolerance_2.value = 0.01
			crop_bottom_2.value = 0.77
			crop_left_2.value = 0.24
			crop_right_2.value = 0.24
			crop_top_2.value = 0.1

		if selected_idx == 1:
			fish_kind.button_pressed = true
		elif selected_idx == 2:
			frog_kind.button_pressed = true
		elif selected_idx == 3:
			bee_kind.button_pressed = true
	)

	_load_drawings_from_disk()


func _map_slider(shader: ShaderMaterial, slider: HSlider, param: String) -> void:
	slider.value_changed.connect(func(value):
		shader.set_shader_parameter(param, value)
	)


func _update_setting(kind: String, name: String, value: Variant) -> void:
	match kind:
		"image":
			match name:
				"draw_texture":
					shader1.set_shader_parameter("draw_texture", value)
				"color_key":
					color_key.color = value
					shader1.set_shader_parameter("color_key", value)
				"tolerance":
					tolerance.value = value
					shader1.set_shader_parameter("tolerance", value)
				"crop_left":
					crop_left.value = value
					shader1.set_shader_parameter("crop_left", value)
				"crop_right":
					crop_right.value = value
					shader1.set_shader_parameter("crop_right", value)
				"crop_top":
					crop_top.value = value
					shader1.set_shader_parameter("crop_top", value)
				"crop_bottom":
					crop_bottom.value = value
					shader1.set_shader_parameter("crop_bottom", value)
		"label":
			match name:
				"draw_texture":
					shader2.set_shader_parameter("draw_texture", value)
				"color_key":
					color_key_2.color = value
					shader2.set_shader_parameter("color_key", value)
				"tolerance":
					tolerance_2.value = value
					shader2.set_shader_parameter("tolerance", value)
				"crop_left":
					crop_left_2.value = value
					shader2.set_shader_parameter("crop_left", value)
				"crop_right":
					crop_right_2.value = value
					shader2.set_shader_parameter("crop_right", value)
				"crop_top":
					crop_top_2.value = value
					shader2.set_shader_parameter("crop_top", value)
				"crop_bottom":
					crop_bottom_2.value = value
					shader2.set_shader_parameter("crop_bottom", value)


func _load_image_from_path(path: String) -> void:
	var img := Image.load_from_file(path)
	img.rotate_90(CLOCKWISE)
	img.resize(512, 288)
	_image = img

	var tex := ImageTexture.create_from_image(img)
	shader1.set_shader_parameter("draw_texture", tex)
	shader2.set_shader_parameter("draw_texture", tex)


func _load_image_from_base64(width: int, height: int, data: String) -> void:
	var img := Image.create_empty(width, height, true, Image.FORMAT_RGB8)
	img.load_jpg_from_buffer(Marshalls.base64_to_raw(data))
	_image = img

	var img_tex := ImageTexture.create_from_image(img)
	shader1.set_shader_parameter("draw_texture", img_tex)
	shader2.set_shader_parameter("draw_texture", img_tex)


func _get_selected_animal_kind() -> String:
	if bee_kind.button_pressed:
		return "bee"
	elif frog_kind.button_pressed:
		return "frog"
	else:
		return "fish"


func _update_configuration_from_drawing(drawing_data: Dictionary) -> void:
	_load_image_from_base64(drawing_data["width"] as int, drawing_data["height"] as int, drawing_data["image"] as String)

	# _update_setting("image", "color_key", Color.html(drawing_data["main"]["color_key"]))
	_update_setting("image", "tolerance", drawing_data["main"]["tolerance"])
	_update_setting("image", "crop_left", drawing_data["main"]["crop_left"])
	_update_setting("image", "crop_right", drawing_data["main"]["crop_right"])
	_update_setting("image", "crop_top", drawing_data["main"]["crop_top"])
	_update_setting("image", "crop_bottom", drawing_data["main"]["crop_bottom"])
	# _update_setting("label", "color_key", Color.html(drawing_data["label"]["color_key"]))
	_update_setting("label", "tolerance", drawing_data["label"]["tolerance"])
	_update_setting("label", "crop_left", drawing_data["label"]["crop_left"])
	_update_setting("label", "crop_right", drawing_data["label"]["crop_right"])
	_update_setting("label", "crop_top", drawing_data["label"]["crop_top"])
	_update_setting("label", "crop_bottom", drawing_data["label"]["crop_bottom"])

	var animal_kind := drawing_data["animal"] as String
	match animal_kind:
		"bee":
			bee_kind.button_pressed = true
		"frog":
			frog_kind.button_pressed = true
		"fish":
			fish_kind.button_pressed = true

	drawing_name.text = drawing_data["name"]


func _prepare_dump() -> Dictionary:
	var image_data = {
		# "color_key": color_key.color.to_html(),
		"tolerance": tolerance.value,
		"crop_left": crop_left.value,
		"crop_right": crop_right.value,
		"crop_top": crop_top.value,
		"crop_bottom": crop_bottom.value,
	}

	var label_data = {
		# "color_key": color_key_2.color.to_html(),
		"tolerance": tolerance_2.value,
		"crop_left": crop_left_2.value,
		"crop_right": crop_right_2.value,
		"crop_top": crop_top_2.value,
		"crop_bottom": crop_bottom_2.value,
	}

	var output = {
		"name": drawing_name.text,
		"animal": _get_selected_animal_kind(),
		"main": image_data,
		"label": label_data,
		"width": 512,
		"height": 288,
		"image": Marshalls.raw_to_base64(_image.save_jpg_to_buffer()),
	}

	return output


func _submit_drawing(dump: Dictionary) -> void:
	_send_json_to_server({
		"kind": "submit-drawing",
		"data": dump
	})


func _send_json_to_server(data: Dictionary) -> void:
	var data_to_json = JSON.stringify(data)
	_client.send(data_to_json)


func _load_drawings_from_disk() -> void:
	var data_as_str := FileAccess.get_file_as_string("user://local-drawings.json")
	if data_as_str == "":
		return

	var json_data := JSON.parse_string(data_as_str) as Dictionary

	var d_keys: Array[String] = []
	for d_name in json_data.keys():
		d_keys.append(d_name)
	d_keys.sort()

	for key in d_keys:
		var d_data := json_data[key] as Dictionary
		var line := _add_local_drawing_line(d_data)

		_local_drawing_data.push_back(d_data)
		_local_drawing_data_index[d_data["name"]] = d_data
		_local_drawing_data_lines[d_data["name"]] = line


func _add_local_drawing_line(data: Dictionary) -> Control:
	var entry := local_drawing_line_template.duplicate()
	entry.visible = true

	entry.get_node("DrawingNameLabel").text = data["name"]
	entry.get_node("DrawingLoadButton").pressed.connect(func():
		_update_configuration_from_drawing(_local_drawing_data_index[data["name"]])
	)
	entry.get_node("DrawingDeleteButton").pressed.connect(func():
		_delete_local_drawing(data["name"])
	)

	var parent := local_drawing_line_template.get_parent()
	parent.add_child(entry)

	return entry


func _create_or_update_current_local_drawing() -> void:
	var dump = _prepare_dump()
	var local_drawing_name = dump["name"]
	if _local_drawing_data_index.has(local_drawing_name):
		_local_drawing_data_index[local_drawing_name] = dump
	else:
		_local_drawing_data.push_back(dump)
		_local_drawing_data_index[local_drawing_name] = dump
		var line := _add_local_drawing_line(dump)
		_local_drawing_data_lines[local_drawing_name] = line

	_save_local_drawings_to_disk()


func _delete_local_drawing(d_name: String) -> void:
	var item := _local_drawing_data_index[d_name] as Dictionary
	_local_drawing_data.erase(item)
	_local_drawing_data_index.erase(d_name)
	_local_drawing_data_lines[d_name].queue_free()
	_local_drawing_data_lines.erase(d_name)

	_save_local_drawings_to_disk()


func _save_local_drawings_to_disk() -> void:
	var file := FileAccess.open("user://local-drawings.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(_local_drawing_data_index))
