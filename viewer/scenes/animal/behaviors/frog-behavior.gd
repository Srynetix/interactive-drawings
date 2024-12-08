extends GAnimalBehavior
class_name GFrogBehavior

const GRAVITY: float = 10.0

var _jump_timer := Timer.new()
var _jumping: bool = false

func _ready() -> void:
	_jump_timer.wait_time = randf_range(1.0, 3.0)
	_jump_timer.autostart = false
	_jump_timer.one_shot = true
	_jump_timer.timeout.connect(func():
		var rand_x := randf_range(-1, 1) * 3.0
		var rand_y := randf_range(-1, 1) * 3.0
		animal.velocity += Vector3.UP * 5 + Vector3.LEFT * rand_x + Vector3.FORWARD * rand_y
		_jumping = true
	)
	add_child(_jump_timer)

	animal.transform = animal.transform.rotated_local(animal.transform.basis.y, randf_range(0.0, 2.0 * PI))

func _process(delta: float) -> void:
	if animal.is_on_floor():
		if _jumping:
			_jumping = false
		else:
			animal.velocity = Vector3.ZERO

		if _jump_timer.is_stopped():
			_jump_timer.start()

	animal.velocity += Vector3.DOWN * GRAVITY * delta
	animal.move_and_slide()