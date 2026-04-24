@tool
extends Node2D
class_name FakePointLight2D

@export_tool_button("Force Update") var force_update: Callable = _update.bind()
@export var mask_light_id: int = 0
@export_range(0.0, 15.0) var energy: float = 1.0
@export_color_no_alpha var light_color: Color = Color.WHITE

var global_visible: bool = false

func _update() -> void:
	global_visible = is_visible_in_tree()
	LightManager.force_update()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	LightManager.force_update()
	LightManager.create_buffer()

func _enter_tree() -> void:
	global_visible = is_visible_in_tree()
	LightManager.load_array_masks()
	LightManager.create_buffer()
	LightManager.register_light(self)

func _exit_tree() -> void:
	LightManager.unregister_light(self)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		global_visible = is_visible_in_tree()
