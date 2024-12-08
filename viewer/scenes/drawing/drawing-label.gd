extends MeshInstance3D
class_name GDrawingLabelMesh

@export var texture_image: Texture2D

func _ready() -> void:
    reload_texture_image()

func reload_texture_image() -> void:
    var quad_mesh := mesh as QuadMesh
    var material := quad_mesh.material as ShaderMaterial
    material.set_shader_parameter("draw_texture", texture_image)

func get_shader() -> ShaderMaterial:
    return mesh.material as ShaderMaterial