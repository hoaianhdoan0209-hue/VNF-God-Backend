extends Node

var _scan_timer: float = 0.0
var _bound_player_id: int = 0
var _ring_texture: Texture2D
var _pixel_texture: Texture2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ring_texture = _make_ring_texture(32)
	_pixel_texture = _make_pixel_texture()

func _process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.30
		_bind_player_if_needed()

func _bind_player_if_needed() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player: Node = players[0]
	if not is_instance_valid(player):
		return
	var id: int = player.get_instance_id()
	if id == _bound_player_id:
		return

	var combat: Node = player.get_node_or_null("Combat")
	var hurtbox: Node = player.get_node_or_null("Hurtbox")
	if combat == null:
		return

	_bound_player_id = id

	if combat.has_signal("dash_started") and not combat.dash_started.is_connected(_on_dash_started):
		combat.dash_started.connect(_on_dash_started.bind(player))
	if combat.has_signal("parry_started") and not combat.parry_started.is_connected(_on_parry_started):
		combat.parry_started.connect(_on_parry_started.bind(player))
	if combat.has_signal("perfect_parry") and not combat.perfect_parry.is_connected(_on_perfect_parry):
		combat.perfect_parry.connect(_on_perfect_parry.bind(player))
	if hurtbox != null and hurtbox.has_signal("hit_received") and not hurtbox.hit_received.is_connected(_on_player_hit):
		hurtbox.hit_received.connect(_on_player_hit.bind(player))

func _on_dash_started(player: Node) -> void:
	if not (player is Node2D):
		return
	var visual: CanvasItem = _find_visual_item(player)
	if visual == null:
		return
	for i in range(4):
		var delay: float = float(i) * 0.045
		var timer: SceneTreeTimer = get_tree().create_timer(delay)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(player) and is_instance_valid(visual):
				_spawn_afterimage(player as Node2D, visual, i)
		)

func _on_parry_started(player: Node) -> void:
	if player is Node2D:
		_spawn_ring(player as Node2D, Color(0.32, 0.82, 1.0, 0.92), 0.58, 1.15, 0.30)
		_spawn_sparks(player as Node2D, Color(0.28, 0.82, 1.0, 0.92), 10, 28.0, 52.0)

func _on_perfect_parry(player: Node) -> void:
	if player is Node2D:
		_spawn_ring(player as Node2D, Color(1.0, 0.86, 0.28, 1.0), 0.55, 1.75, 0.42)
		_spawn_ring(player as Node2D, Color(1.0, 0.46, 0.12, 0.78), 0.30, 1.35, 0.32)
		_spawn_sparks(player as Node2D, Color(1.0, 0.74, 0.18, 1.0), 24, 48.0, 105.0)

func _on_player_hit(_payload: Dictionary, player: Node) -> void:
	if not (player is Node2D):
		return
	var visual: CanvasItem = _find_visual_item(player)
	if visual != null:
		var original: Color = visual.modulate
		visual.modulate = Color(1.35, 0.32, 0.26, original.a)
		var tween: Tween = player.create_tween()
		tween.tween_property(visual, "modulate", original, 0.16)
	_spawn_sparks(player as Node2D, Color(1.0, 0.22, 0.12, 0.95), 14, 24.0, 72.0)

func _spawn_afterimage(player: Node2D, visual: CanvasItem, index: int) -> void:
	var texture: Texture2D = _extract_texture(visual)
	if texture == null:
		return
	var root: Node = get_tree().current_scene
	if root == null:
		return

	var ghost := Sprite2D.new()
	ghost.name = "V46DashGhost"
	ghost.texture = texture
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.z_index = 42
	ghost.modulate = Color(0.24, 0.72, 1.0, 0.34 - float(index) * 0.045)
	root.add_child(ghost)

	if visual is Node2D:
		var visual_2d := visual as Node2D
		ghost.global_position = visual_2d.global_position
		ghost.global_rotation = visual_2d.global_rotation
		ghost.global_scale = visual_2d.global_scale

	if visual is Sprite2D:
		var sprite := visual as Sprite2D
		ghost.flip_h = sprite.flip_h
		ghost.flip_v = sprite.flip_v
		ghost.offset = sprite.offset

	var facing: float = 1.0
	if player.velocity.x < 0.0:
		facing = -1.0
	ghost.global_position.x -= facing * float(index + 1) * 5.0

	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.24)
	tween.tween_property(ghost, "scale", ghost.scale * 0.96, 0.24)
	tween.set_parallel(false)
	tween.tween_callback(ghost.queue_free)

func _spawn_ring(player: Node2D, color: Color, start_scale: float, end_scale: float, duration: float) -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	var ring := Sprite2D.new()
	ring.name = "V46ParryRing"
	ring.texture = _ring_texture
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ring.modulate = color
	ring.scale = Vector2.ONE * start_scale
	ring.z_index = 95
	root.add_child(ring)
	ring.global_position = player.global_position + Vector2(0, -24)

	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * end_scale, duration)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.set_parallel(false)
	tween.tween_callback(ring.queue_free)

func _spawn_sparks(player: Node2D, color: Color, amount: int, speed_min: float, speed_max: float) -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	var p := CPUParticles2D.new()
	p.name = "V46CombatSparks"
	p.texture = _pixel_texture
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.global_position = player.global_position + Vector2(0, -24)
	p.z_index = 96
	p.amount = amount
	p.lifetime = 0.50
	p.one_shot = true
	p.explosiveness = 0.92
	p.local_coords = false
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.gravity = Vector2(0, 80)
	p.scale_amount_min = 0.75
	p.scale_amount_max = 1.45
	p.color = color
	root.add_child(p)
	p.emitting = true

	var timer: SceneTreeTimer = get_tree().create_timer(1.0)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)

func _find_visual_item(root: Node) -> CanvasItem:
	var preferred: Node = root.get_node_or_null("Visual")
	if preferred != null:
		var found: CanvasItem = _find_first_canvas_visual(preferred)
		if found != null:
			return found
	return _find_first_canvas_visual(root)

func _find_first_canvas_visual(root: Node) -> CanvasItem:
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Sprite2D or node is AnimatedSprite2D:
			return node as CanvasItem
		var children: Array[Node] = node.get_children()
		for child in children:
			var lower: String = String(child.name).to_lower()
			if not lower.begins_with("v44") and not lower.begins_with("v45") and not lower.begins_with("v46"):
				pending.append(child)
	return null

func _extract_texture(visual: CanvasItem) -> Texture2D:
	if visual is Sprite2D:
		return (visual as Sprite2D).texture
	if visual is AnimatedSprite2D:
		var anim := visual as AnimatedSprite2D
		if anim.sprite_frames != null and anim.sprite_frames.has_animation(anim.animation):
			return anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	return null

func _make_ring_texture(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(float(size - 1) * 0.5, float(size - 1) * 0.5)
	var radius: float = float(size) * 0.38
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(float(x), float(y)).distance_to(center)
			if absf(d - radius) <= 1.25:
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)

func _make_pixel_texture() -> Texture2D:
	var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.set_pixel(1, 0, Color.WHITE)
	img.set_pixel(0, 1, Color.WHITE)
	img.set_pixel(1, 1, Color.WHITE)
	img.set_pixel(2, 1, Color.WHITE)
	img.set_pixel(1, 2, Color.WHITE)
	return ImageTexture.create_from_image(img)
