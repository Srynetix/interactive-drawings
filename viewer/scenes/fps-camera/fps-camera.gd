extends Camera3D

const MOVE_SPEED: float = 5.0
const LOOK_SPEED: float = 0.1
const FAST_MULTIPLICATOR: float = 4.0

var _rotation_helper: Node3D
var _is_ready: bool = false
var _is_captured: bool = false


func _ready() -> void:
    _rotation_helper = Node3D.new()
    _rotation_helper.name = "RotationHelper"

    # Rebuild tree
    add_sibling.call_deferred(_rotation_helper)
    _rotation_helper.transform = transform
    reparent.call_deferred(_rotation_helper)

    set_deferred("_is_ready", true)

    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _is_captured = true


func _process(delta: float) -> void:
    if not _is_ready:
        return

    var move_speed := MOVE_SPEED
    if Input.is_action_pressed("run"):
        move_speed *= FAST_MULTIPLICATOR

    if Input.is_action_pressed("move_forward"):
        _rotation_helper.transform = _rotation_helper.transform.translated(move_speed * -_rotation_helper.transform.basis.z * delta)
    elif Input.is_action_pressed("move_backward"):
        _rotation_helper.transform = _rotation_helper.transform.translated(move_speed * _rotation_helper.transform.basis.z * delta)

    if Input.is_action_pressed("strafe_left"):
        _rotation_helper.transform = _rotation_helper.transform.translated(move_speed * -_rotation_helper.transform.basis.x * delta)
    elif Input.is_action_pressed("strafe_right"):
        _rotation_helper.transform = _rotation_helper.transform.translated(move_speed * _rotation_helper.transform.basis.x * delta)

    if Input.is_action_pressed("move_up"):
        _rotation_helper.transform = _rotation_helper.transform.translated(move_speed * _rotation_helper.transform.basis.y * delta)
    elif Input.is_action_pressed("move_down"):
        _rotation_helper.transform = _rotation_helper.transform.translated(move_speed * -_rotation_helper.transform.basis.y * delta)


func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        if not _is_ready:
            return

        if not _is_captured:
            return

        var mouse_velocity := event.relative as Vector2
        if mouse_velocity.x != 0:
            _rotation_helper.transform = _rotation_helper.transform.rotated_local(_rotation_helper.transform.basis.y, LOOK_SPEED * 0.016 * -mouse_velocity.x)
        if mouse_velocity.y != 0:
            transform = transform.rotated_local(transform.basis.x, LOOK_SPEED * 0.016 * -mouse_velocity.y)

    if event is InputEventKey:
        if event.pressed and event.keycode == KEY_ESCAPE:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
            _is_captured = false

    if event is InputEventMouseButton:
        if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
                Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
                _is_captured = true