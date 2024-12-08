extends CharacterBody3D
class_name GAnimal

enum AnimalBehaviorEnum {
    Fish,
    Frog,
    Bee
}

@export var behavior_enum: AnimalBehaviorEnum
@export var texture_image: Texture2D

@onready var drawing_mesh := $DrawingMesh as GDrawingMesh

var _behavior: GAnimalBehavior = null

func _ready() -> void:
    if behavior_enum == AnimalBehaviorEnum.Fish:
        _behavior = GFishBehavior.new()
    elif behavior_enum == AnimalBehaviorEnum.Frog:
        _behavior = GFrogBehavior.new()
    else:
        _behavior = GBeeBehavior.new()

    _behavior.animal = self
    add_child(_behavior)

func reload_texture_image() -> void:
    drawing_mesh.texture_image = texture_image
    drawing_mesh.reload_texture_image()