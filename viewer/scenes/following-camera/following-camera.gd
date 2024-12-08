extends Camera3D
class_name GFollowingCamera

@export var focus_time: int = 3
@export var z_distance: float = 4.0
@export var y_distance: float = 1.0


class TrackedNode:
    extends RefCounted

    var target: Node3D
    var drawing_name: String


var _tracked_nodes: Array[TrackedNode] = []
var _tracked_nodes_index: Dictionary = {}
var _current_tracked_node: int = -1
var _elapsed_time: float = 0.0

func _process(delta: float) -> void:
    if _current_tracked_node != -1:
        var node := _tracked_nodes[_current_tracked_node]
        var target_position := node.target.global_transform.origin + node.target.global_transform.basis.z * z_distance + node.target.global_transform.basis.y * y_distance
        look_at_from_position(target_position, node.target.global_position)

    # Change if needed
    _elapsed_time += delta
    if _elapsed_time > focus_time:
        if _current_tracked_node != -1:
            _current_tracked_node = (_current_tracked_node + 1) % len(_tracked_nodes)
        _elapsed_time = 0.0


func track_new_node(drawing_name: String, node: Node3D) -> void:
    var wrapper := TrackedNode.new()
    wrapper.target = node
    wrapper.drawing_name = drawing_name
    _tracked_nodes.push_back(wrapper)

    _current_tracked_node = len(_tracked_nodes) - 1
    _elapsed_time = 0
    _tracked_nodes_index[drawing_name] = _current_tracked_node

    if _current_tracked_node > -1:
        current = true


func focus_existing_node(drawing_name: String) -> void:
    var index := _tracked_nodes_index[drawing_name] as int
    _current_tracked_node = index
    _elapsed_time = 0


func stop_focusing_node(drawing_name: String) -> void:
    var index := _tracked_nodes_index[drawing_name] as int
    if len(_tracked_nodes) > 1:
        _tracked_nodes.remove_at(index)
        _current_tracked_node = min(index, len(_tracked_nodes) - 1)
        _rebuild_index()
    else:
        _current_tracked_node = -1
        _tracked_nodes.clear()
        _tracked_nodes_index.clear()
        current = false


func _rebuild_index() -> void:
    var cursor := 0
    for wrapper in _tracked_nodes:
        _tracked_nodes_index[wrapper.drawing_name] = cursor
        cursor += 1
