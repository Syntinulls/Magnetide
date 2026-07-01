extends Node2D
class_name CompositeOutline

## Draws a single outline around the combined silhouette of several sprites.
##
## All source sprites are mirrored into an off-screen SubViewport to produce one
## combined silhouette texture. That texture is NOT displayed directly; it only
## feeds `composite_outline.gdshader`, which emits just the outline ring. The
## real sprites keep rendering normally underneath, so the interior is untouched
## and overlapping sprites yield one clean outline instead of per-sprite edges.
##
## Add as a child (at identity transform) of the object whose sprites should be
## outlined, then call configure() with the source sprites. Toggle via
## set_enabled(); recolor via set_color(); rebuild after the sprite set / stack
## changes via refresh().

const OUTLINE_SHADER: Shader = preload("res://_project/shaders/composite_outline.gdshader")

var _sources: Array[CanvasItem] = []
var _active_sources: Array[CanvasItem] = []
var _mirrors: Array[Sprite2D] = []
var _viewport: SubViewport = null
var _mirror_root: Node2D = null
var _layer: Sprite2D = null
var _material: ShaderMaterial = null

var _dynamic: bool = false
var _enabled: bool = false
var _color: Color = Color.WHITE
var _width: float = 3.0
var _padding: float = 6.0
## Node whose z_index / z_as_relative the outline layer mirrors so the outline
## draws at the exact same depth as the object it outlines. Must share a parent
## with this CompositeOutline (i.e. be a sibling) so the z base matches.
var _z_source: CanvasItem = null
## Optional per-object bounds override (in the object's local space). When set to
## a positive-size rect it defines the render box directly, guaranteeing every
## child sprite is encompassed regardless of the auto-computed extents. Padding
## is still added around it for the outline ring.
var _explicit_bounds: Rect2 = Rect2()


## `sources`: the sprites to outline (Sprite2D / AnimatedSprite2D). `dynamic`:
## set true when the sources animate or move relative to the parent (re-syncs
## every frame while enabled); false for static sprites (renders once on change).
## `z_source`: the sprite whose exact z the outline should match (defaults to the
## first source). It should be a sibling of this node so their z base agrees.
## `padding`: transparent margin (px) added around the silhouette so the full
## outline ring always fits — even for sprites whose texture has no transparent
## border. Pass < 0 for a generous default. `bounds`: optional explicit render
## box (object-local space); when its size is positive it overrides the
## auto-computed extents so every child is guaranteed inside the viewport.
func configure(sources: Array, dynamic: bool = false, color: Color = Color.WHITE, width: float = 3.0, z_source: CanvasItem = null, padding: float = -1.0, bounds: Rect2 = Rect2()) -> void:
	_sources.clear()
	for s in sources:
		var ci := s as CanvasItem
		if ci != null:
			_sources.append(ci)
	_dynamic = dynamic
	_color = color
	_width = width
	# Default margin scales with the outline width so the ring always has room.
	_padding = padding if padding >= 0.0 else maxf(width * 2.0 + 4.0, 8.0)
	_z_source = z_source
	if _z_source == null and not _sources.is_empty():
		_z_source = _sources[0]
	_explicit_bounds = bounds
	_ensure_nodes()
	_position_after_z_source()
	refresh()
	set_process(_dynamic and _enabled)


## Move this node (and its outline layer) to sit immediately after the z_source
## sibling in the tree. z_index ties are broken by tree order, so without this a
## dynamically-added outline draws after everything (e.g. on top of the player)
## even when its z_index matches a sprite that renders below.
func _position_after_z_source() -> void:
	if _z_source == null or not is_instance_valid(_z_source):
		return
	var parent := get_parent()
	if parent == null or _z_source.get_parent() != parent:
		return
	var z_idx := _z_source.get_index()
	var target := z_idx if get_index() < z_idx else z_idx + 1
	parent.move_child(self, target)


func set_enabled(enabled: bool) -> void:
	if _layer == null:
		_ensure_nodes()
	_enabled = enabled
	_layer.visible = enabled
	if enabled:
		_update_geometry()
		if _dynamic:
			_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		else:
			_request_single_render()
	else:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	set_process(_dynamic and _enabled)


func set_color(color: Color) -> void:
	_color = color
	if _material != null:
		_material.set_shader_parameter("outline_color", color)


## Rebuild mirrors and geometry after the visible sprite set changes (e.g. a
## salvage stack growing) or a sprite's texture is (re)assigned.
func refresh() -> void:
	_ensure_nodes()
	_rebuild_mirrors()
	_update_geometry()
	if _enabled and not _dynamic:
		_request_single_render()


func _process(_delta: float) -> void:
	if not _enabled:
		return
	# Sources animate / move: re-sync mirrors each frame (viewport re-renders via
	# UPDATE_ALWAYS while enabled).
	if _active_source_set_changed():
		_rebuild_mirrors()
	_update_geometry()


func _ensure_nodes() -> void:
	if _viewport == null:
		_viewport = SubViewport.new()
		_viewport.name = "OutlineViewport"
		_viewport.transparent_bg = true
		_viewport.disable_3d = true
		_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_viewport.size = Vector2i(4, 4)
		add_child(_viewport)
		_mirror_root = Node2D.new()
		_mirror_root.name = "MirrorRoot"
		_viewport.add_child(_mirror_root)
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = OUTLINE_SHADER
	if _layer == null:
		_layer = Sprite2D.new()
		_layer.name = "OutlineLayer"
		_layer.centered = true
		_layer.material = _material
		_layer.visible = false
		add_child(_layer)
	_material.set_shader_parameter("outline_color", _color)
	_material.set_shader_parameter("outline_width", _width)
	_sync_layer_z()


## Match the outline layer's draw depth to the source sprite exactly, so the
## outline never renders in front of / behind things the item itself doesn't.
func _sync_layer_z() -> void:
	if _layer == null or _z_source == null or not is_instance_valid(_z_source):
		return
	_layer.z_as_relative = _z_source.z_as_relative
	_layer.z_index = _z_source.z_index


func _request_single_render() -> void:
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _collect_active() -> Array[CanvasItem]:
	var active: Array[CanvasItem] = []
	for src in _sources:
		if is_instance_valid(src) and src.visible and _source_texture(src) != null:
			active.append(src)
	return active


func _active_source_set_changed() -> bool:
	var current := _collect_active()
	if current.size() != _active_sources.size():
		return true
	for i in range(current.size()):
		if current[i] != _active_sources[i]:
			return true
	return false


func _rebuild_mirrors() -> void:
	for m in _mirrors:
		if is_instance_valid(m):
			m.queue_free()
	_mirrors.clear()
	_active_sources = _collect_active()
	for _src in _active_sources:
		var mirror := Sprite2D.new()
		_mirror_root.add_child(mirror)
		_mirrors.append(mirror)


func _update_geometry() -> void:
	if _layer == null:
		return
	if _active_sources.is_empty():
		_layer.visible = false
		return

	# An explicit per-object box (if configured) is unioned with the auto extents
	# so it can only ever grow the coverage, never clip a child that spills past it.
	var bbox := _compute_bbox()
	if _explicit_bounds.size.x > 0.0 and _explicit_bounds.size.y > 0.0:
		bbox = _explicit_bounds if bbox.size.x <= 0.0 else bbox.merge(_explicit_bounds)
	if bbox.size.x <= 0.0 or bbox.size.y <= 0.0:
		_layer.visible = _enabled
		return

	var pad := Vector2(_padding, _padding)
	var vp_size := bbox.size + pad * 2.0
	var vp_size_i := Vector2i(int(ceil(vp_size.x)), int(ceil(vp_size.y)))
	if _viewport.size != vp_size_i:
		_viewport.size = vp_size_i

	# Viewport-space = object-root-space + offset (so the bbox sits at `pad`).
	var offset := pad - bbox.position
	for i in range(_mirrors.size()):
		_sync_mirror(_active_sources[i], _mirrors[i], offset)

	_layer.texture = _viewport.get_texture()
	_layer.position = bbox.get_center()
	_layer.visible = _enabled
	_sync_layer_z()


func _sync_mirror(src: CanvasItem, mirror: Sprite2D, offset: Vector2) -> void:
	mirror.texture = _source_texture(src)
	mirror.centered = _source_centered(src)
	if src is Sprite2D:
		var s := src as Sprite2D
		mirror.flip_h = s.flip_h
		mirror.flip_v = s.flip_v
		mirror.region_enabled = s.region_enabled
		mirror.region_rect = s.region_rect
		mirror.offset = s.offset
	elif src is AnimatedSprite2D:
		var a := src as AnimatedSprite2D
		mirror.flip_h = a.flip_h
		mirror.flip_v = a.flip_v
		mirror.offset = a.offset

	var rel := _rel_xform(src)
	rel.origin += offset
	mirror.transform = rel


func _compute_bbox() -> Rect2:
	var bbox := Rect2()
	var first := true
	for src in _active_sources:
		var r := _source_local_rect(src)
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		if first:
			bbox = r
			first = false
		else:
			bbox = bbox.merge(r)
	return bbox


func _source_local_rect(src: CanvasItem) -> Rect2:
	var tex := _source_texture(src)
	if tex == null:
		return Rect2()
	var sz := tex.get_size()
	if src is Sprite2D and (src as Sprite2D).region_enabled:
		sz = (src as Sprite2D).region_rect.size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return Rect2()

	# Sprite2D/AnimatedSprite2D `offset` shifts where the texture draws relative to
	# the node origin, so the silhouette rect must include it — otherwise the
	# viewport is centered on the origin and clips offset sprites (e.g. a lever
	# handle drawn well above its pivot), dropping the outline there.
	var off := _source_offset(src)
	var local_rect: Rect2
	if _source_centered(src):
		local_rect = Rect2(off - sz * 0.5, sz)
	else:
		local_rect = Rect2(off, sz)

	return _xform_rect(_rel_xform(src), local_rect)


## Transform of `src` relative to this outline's parent (the object root).
func _rel_xform(src: CanvasItem) -> Transform2D:
	var root := get_parent() as Node2D
	var src2d := src as Node2D
	if root == null or src2d == null or not src2d.is_inside_tree():
		return Transform2D.IDENTITY
	return root.get_global_transform().affine_inverse() * src2d.get_global_transform()


func _source_texture(src: CanvasItem) -> Texture2D:
	if src is Sprite2D:
		return (src as Sprite2D).texture
	if src is AnimatedSprite2D:
		var a := src as AnimatedSprite2D
		if a.sprite_frames != null and a.sprite_frames.has_animation(a.animation):
			return a.sprite_frames.get_frame_texture(a.animation, a.frame)
	return null


func _source_centered(src: CanvasItem) -> bool:
	if src is Sprite2D:
		return (src as Sprite2D).centered
	if src is AnimatedSprite2D:
		return (src as AnimatedSprite2D).centered
	return true


func _source_offset(src: CanvasItem) -> Vector2:
	if src is Sprite2D:
		return (src as Sprite2D).offset
	if src is AnimatedSprite2D:
		return (src as AnimatedSprite2D).offset
	return Vector2.ZERO


func _xform_rect(t: Transform2D, r: Rect2) -> Rect2:
	var p0 := t * r.position
	var p1 := t * (r.position + Vector2(r.size.x, 0.0))
	var p2 := t * (r.position + Vector2(0.0, r.size.y))
	var p3 := t * (r.position + r.size)
	var min_p := p0
	var max_p := p0
	for p in [p1, p2, p3]:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	return Rect2(min_p, max_p - min_p)
