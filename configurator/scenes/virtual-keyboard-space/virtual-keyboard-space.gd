extends MarginContainer
class_name VirtualKeyboardSpace


func _process(delta: float) -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		var margin := DisplayServer.virtual_keyboard_get_height() as float
		margin /= DisplayServer.screen_get_scale()
		add_theme_constant_override("margin_bottom", max(floor(margin), 0))