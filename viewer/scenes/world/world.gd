extends Node3D
class_name GWorld

const ANIMAL_SCENE := preload("res://scenes/animal/animal-with-label.tscn")

@onready var _following_camera := $FollowingCamera as GFollowingCamera
@onready var _fish_spawn_point := %FishSpawnPoint as Marker3D
@onready var _frog_spawn_point := %FrogSpawnPoint as Marker3D
@onready var _bee_spawn_point := %BeeSpawnPoint as Marker3D


const BIND_PORT = 8123

var _server: WebSocketServer

var _drawings_data: Dictionary = {}
var _drawings: Dictionary = {}


func _ready() -> void:
	_server = WebSocketServer.new()
	add_child(_server)

	_server.client_connected.connect(func(id):
		print("Peer connected: %d" % id)
	)

	_server.client_disconnected.connect(func(id):
		print("Peer disconnected: %d" % id)
	)

	_server.message_received.connect(func(id, msg):
		print("Message received from %d: %s" % [id, msg])
		var json_data := JSON.parse_string(msg) as Dictionary
		var kind := json_data["kind"] as String
		if kind == "submit-drawing":
			# Write payload
			var dump := FileAccess.open("user://payload.json", FileAccess.WRITE)
			dump.store_string(msg)

			var submit_data := json_data["data"] as Dictionary

			var drawing_name := submit_data["name"] as String
			var width := submit_data["width"] as int
			var height := submit_data["height"] as int
			var image := submit_data["image"] as String
			var image_params := submit_data["main"] as Dictionary
			var label_params := submit_data["label"] as Dictionary
			var animal_kind := submit_data["animal"] as String
			
			if _drawings_data.has(drawing_name):
				# That's an update
				_update_drawing(drawing_name, width, height, image_params, label_params, animal_kind, image)
			else:
				_spawn_drawing(drawing_name, width, height, image_params, label_params, animal_kind, image)
			
			_send_all_drawings(id)

		elif kind == "get-drawings":
			_send_all_drawings(id)

		elif kind == "delete-drawing":
			# Delete drawing
			var drawing_name := json_data["name"] as String
			_following_camera.stop_focusing_node(drawing_name)

			_drawings[drawing_name].queue_free()
			_drawings_data.erase(drawing_name)
			
			_send_all_drawings(id)

		elif kind == "focus-drawing":
			# Focus drawing
			var drawing_name := json_data["name"] as String
			_following_camera.focus_existing_node(drawing_name)

		elif kind == "get-config":
			_server.send(id, JSON.stringify({
				"kind": "get-config-response",
				"camera_focus_time": _following_camera.focus_time,
				"camera_z_distance": _following_camera.z_distance,
				"camera_y_distance": _following_camera.y_distance,
			}))

		elif kind == "set-config":
			_following_camera.focus_time = json_data["camera_focus_time"]
			_following_camera.z_distance = json_data["camera_z_distance"]
			_following_camera.y_distance = json_data["camera_y_distance"]
	)

	_server.listen(BIND_PORT)


func _send_all_drawings(peer_id: int) -> void:
	# Dump all drawings
	var data := _dump_all_drawings()
	var message := {
		"kind": "get-drawings-response",
		"drawings": data
	}
	_server.send(peer_id, JSON.stringify(message))


func _update_drawing(drawing_name: String, width: int, height: int, image_params: Dictionary, label_params: Dictionary, animal_kind: String, drawing: String) -> void:
	var img := Image.create_empty(width, height, true, Image.FORMAT_RGB8)
	img.load_jpg_from_buffer(Marshalls.base64_to_raw(drawing))
	var img_tex := ImageTexture.create_from_image(img)

	var behavior_enum = GAnimal.AnimalBehaviorEnum.Bee
	if animal_kind == "fish":
		behavior_enum = GAnimal.AnimalBehaviorEnum.Fish
	elif animal_kind == "frog":
		behavior_enum = GAnimal.AnimalBehaviorEnum.Frog

	var scene := _drawings[drawing_name] as GAnimalWithLabel
	scene.behavior_enum = behavior_enum
	scene.texture_image = img_tex
	scene.animal_parameters = image_params
	scene.label_parameters = label_params
	_set_animal_position_at_spawn(scene)
	scene.reload_data()

	_drawings_data[drawing_name] = {
		"name": drawing_name,
		"width": width,
		"height": height,
		"main": image_params,
		"label": label_params,
		"animal": animal_kind,
		"image": drawing
	}

	_following_camera.focus_existing_node(drawing_name)


func _spawn_drawing(drawing_name: String, width: int, height: int, image_params: Dictionary, label_params: Dictionary, animal_kind: String, drawing: String) -> void:
	var img := Image.create_empty(width, height, true, Image.FORMAT_RGB8)
	img.load_jpg_from_buffer(Marshalls.base64_to_raw(drawing))
	var img_tex := ImageTexture.create_from_image(img)

	var behavior_enum = GAnimal.AnimalBehaviorEnum.Bee
	if animal_kind == "fish":
		behavior_enum = GAnimal.AnimalBehaviorEnum.Fish
	elif animal_kind == "frog":
		behavior_enum = GAnimal.AnimalBehaviorEnum.Frog

	var scene := ANIMAL_SCENE.instantiate() as GAnimalWithLabel
	scene.behavior_enum = behavior_enum
	scene.texture_image = img_tex
	scene.animal_parameters = image_params
	scene.label_parameters = label_params
	_set_animal_position_at_spawn(scene)
	add_child(scene)

	_drawings[drawing_name] = scene
	_drawings_data[drawing_name] = {
		"name": drawing_name,
		"width": width,
		"height": height,
		"main": image_params,
		"label": label_params,
		"animal": animal_kind,
		"image": drawing
	}

	_following_camera.track_new_node(drawing_name, scene.get_node("Label"))


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_0:
			var data_str := FileAccess.get_file_as_string("user://payload.json")
			var data := JSON.parse_string(data_str) as Dictionary
			_spawn_drawing(
				data["data"]["name"],
				data["data"]["width"],
				data["data"]["height"],
				data["data"]["main"],
				data["data"]["label"],
				data["data"]["animal"],
				data["data"]["image"]
			)

func _dump_drawing(drawing_name: String) -> Dictionary:
	return _drawings_data[drawing_name]


func _dump_all_drawings() -> Array[Dictionary]:
	var drawings: Array[Dictionary] = []
	var drawing_names: Array[String] = []

	for drawing_name in _drawings_data.keys():
		drawing_names.push_back(drawing_name)

	drawing_names.sort()
	for drawing_name in drawing_names:
		drawings.push_back(_drawings_data[drawing_name] as Dictionary)

	return drawings


func _set_animal_position_at_spawn(scene: GAnimalWithLabel) -> void:
	var spawn_position := Vector3.ZERO

	match scene.behavior_enum:
		GAnimal.AnimalBehaviorEnum.Bee:
			spawn_position = _bee_spawn_point.global_position
		GAnimal.AnimalBehaviorEnum.Fish:
			spawn_position = _fish_spawn_point.global_position
		GAnimal.AnimalBehaviorEnum.Frog:
			spawn_position = _frog_spawn_point.position

	# TODO: Add jitter to position
	scene.position = spawn_position
