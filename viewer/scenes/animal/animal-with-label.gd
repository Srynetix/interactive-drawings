extends Node3D
class_name GAnimalWithLabel

@export var behavior_enum: GAnimal.AnimalBehaviorEnum
@export var texture_image: Texture2D
@export var animal_parameters: Dictionary
@export var label_parameters: Dictionary

@onready var _label = $Label/DrawingLabelMesh as GDrawingLabelMesh
var _animal_instance: GAnimal

const ANIMAL_SCENE := preload("res://scenes/animal/animal.tscn")

func _ready() -> void:
	_animal_instance = ANIMAL_SCENE.instantiate() as GAnimal
	_animal_instance.name = "Animal"
	_animal_instance.behavior_enum = behavior_enum
	add_child(_animal_instance)

	_animal_instance.texture_image = texture_image
	_animal_instance.reload_texture_image()

	$PinJoint3D.node_b = _animal_instance.get_path()
	reload_data()


func reload_data() -> void:
	_label.texture_image = texture_image
	_label.reload_texture_image()

	# Update parameters
	var animal_shader := _animal_instance.drawing_mesh.get_shader() as ShaderMaterial
	var label_shader := _label.get_shader() as ShaderMaterial

	animal_shader.set_shader_parameter("color_key", Color.html(animal_parameters.get("color_key", "#FFFFFF")))
	animal_shader.set_shader_parameter("tolerance", animal_parameters.get("tolerance", 0.0))
	animal_shader.set_shader_parameter("crop_left", animal_parameters.get("crop_left", 0.0))
	animal_shader.set_shader_parameter("crop_right", animal_parameters.get("crop_right", 0.0))
	animal_shader.set_shader_parameter("crop_bottom", animal_parameters.get("crop_bottom", 0.0))
	animal_shader.set_shader_parameter("crop_top", animal_parameters.get("crop_top", 0.0))

	label_shader.set_shader_parameter("color_key", Color.html(label_parameters.get("color_key", "#FFFFFF")))
	label_shader.set_shader_parameter("tolerance", label_parameters.get("tolerance", 0.0))
	label_shader.set_shader_parameter("crop_left", label_parameters.get("crop_left", 0.0))
	label_shader.set_shader_parameter("crop_right", label_parameters.get("crop_right", 0.0))
	label_shader.set_shader_parameter("crop_bottom", label_parameters.get("crop_bottom", 0.0))
	label_shader.set_shader_parameter("crop_top", label_parameters.get("crop_top", 0.0))