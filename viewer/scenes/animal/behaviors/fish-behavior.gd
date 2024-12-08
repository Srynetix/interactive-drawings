extends GAnimalBehavior
class_name GFishBehavior

var _state_processor: StateProcessor
var _angular_velocity: Vector3


class GState:
	extends RefCounted

	var _elapsed_time: float = 0.0

	func _reset(obj: GFishBehavior) -> void:
		_elapsed_time = 0.0

	func _on_enter(obj: GFishBehavior) -> void:
		pass

	func _tick(obj: GFishBehavior, delta: float) -> void:
		_elapsed_time += delta

	func _on_process(obj: GFishBehavior, delta: float) -> String:
		return ""

	func _on_exit(obj: GFishBehavior) -> void:
		pass


class MoveState:
	extends GState

	const MIN_MOVE_SPEED: float = 1.0
	const MAX_MOVE_SPEED: float = 3.0
	const ROTATION_SPEED: float = 0.3
	const MAX_SPEED: float = 5.0

	const NAME := "move"

	var _move_time: float
	var _move_speed: float

	func _on_enter(_obj: GFishBehavior) -> void:
		_move_time = randf_range(5.0, 10.0)
		_move_speed = randf_range(MIN_MOVE_SPEED, MAX_MOVE_SPEED)

	func _on_process(obj: GFishBehavior, delta: float) -> String:
		if _elapsed_time > _move_time:
			return TurnState.NAME
	
		obj._angular_velocity += obj.animal.transform.basis.y * delta * randf_range(-ROTATION_SPEED, ROTATION_SPEED)
		obj.animal.velocity += obj.animal.transform.basis.x * delta * _move_speed
		obj.animal.velocity = obj.animal.velocity.limit_length(MAX_SPEED)
		return ""


class TurnState:
	extends GState

	const NAME := "turn"

	var _turn_time: float

	func _on_enter(_obj: GFishBehavior) -> void:
		_turn_time = randf_range(1.0, 10.0)

	func _on_process(obj: GFishBehavior, delta: float) -> String:
		if _elapsed_time > _turn_time:
			return IdleState.NAME
		
		obj._angular_velocity += obj.animal.transform.basis.y * delta * randf_range(-1, 1)
		return ""


class IdleState:
	extends GState

	const NAME := "idle"

	func _on_process(obj: GFishBehavior, delta: float) -> String:
		if _elapsed_time > 1.0:
			return MoveState.NAME

		obj.animal.velocity *= 1 - delta
		obj._angular_velocity *= 1 - delta
		return ""


class StateProcessor:
	extends RefCounted

	var _obj: GFishBehavior
	var _states: Dictionary = {}
	var _state: GState = null

	func _init(obj: GFishBehavior, states: Dictionary, initial_state: String) -> void:
		_obj = obj
		_states = states
		_state = states[initial_state]
		_state._reset(_obj)
		_state._on_enter(_obj)

	func _process(delta: float) -> void:
		_state._tick(_obj, delta)
		var next_state := _state._on_process(_obj, delta)
		if next_state != "":
			var prev_state := _state
			prev_state._on_exit(_obj)
			_state = _states[next_state]
			_state._reset(_obj)
			_state._on_enter(_obj)
			print("CHANGING STATE TO %s" % next_state)


func _ready() -> void:
	_state_processor = StateProcessor.new(self, {
		MoveState.NAME: MoveState.new(),
		TurnState.NAME: TurnState.new(),
		IdleState.NAME: IdleState.new(),
	}, MoveState.NAME)

	animal.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING

func _process(delta: float) -> void:
	_state_processor._process(delta)

	if _angular_velocity != Vector3.ZERO:
		animal.transform = animal.transform.rotated_local(_angular_velocity.normalized(), _angular_velocity.length() * delta)

	var collision := animal.move_and_collide(animal.velocity * delta)
	if collision:
		var normal := collision.get_normal()

		# Bounce!
		animal.velocity *= normal
		animal.transform = animal.transform.rotated_local(animal.transform.basis.y, PI)
