@tool
extends Sprite2D
class_name NinePatchSprite

@export var target_size: Vector2 = Vector2(128, 128):
	set(value):
		target_size = value
		_update_nine_patch()

@export var margin_left: float = 16.0:
	set(value):
		margin_left = value
		_update_nine_patch()

@export var margin_right: float = 16.0:
	set(value):
		margin_right = value
		_update_nine_patch()

@export var margin_top: float = 16.0:
	set(value):
		margin_top = value
		_update_nine_patch()

@export var margin_bottom: float = 16.0:
	set(value):
		margin_bottom = value
		_update_nine_patch()

var _shader: Shader = preload("res://_project/shaders/nine_patch_sprite.gdshader")


func _ready() -> void:
	_setup_material()
	_update_nine_patch()


func _setup_material() -> void:
	if material == null or not material is ShaderMaterial:
		material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = _shader


func _update_nine_patch() -> void:
	if texture == null:
		return
	
	if material == null or not material is ShaderMaterial:
		_setup_material()
	
	var tex_size := texture.get_size()
	var scale_x := target_size.x / tex_size.x
	var scale_y := target_size.y / tex_size.y
	scale = Vector2(scale_x, scale_y)
	
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("target_size", target_size)
	mat.set_shader_parameter("margin_left", margin_left)
	mat.set_shader_parameter("margin_right", margin_right)
	mat.set_shader_parameter("margin_top", margin_top)
	mat.set_shader_parameter("margin_bottom", margin_bottom)
