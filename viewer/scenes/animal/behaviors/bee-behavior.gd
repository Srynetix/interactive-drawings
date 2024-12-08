extends GAnimalBehavior
class_name GBeeBehavior

const MOVE_SPEED: float = 50.0


func _process(delta: float) -> void:
    var direction := Vector3.ZERO
    direction.x = randf_range(-1.0, 1.0)
    direction.y = randf_range(-1.0, 1.0)
    direction.z = randf_range(-1.0, 1.0)
    direction = direction.normalized()

    animal.velocity += direction * MOVE_SPEED * delta
    animal.move_and_slide()