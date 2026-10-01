extends Node

var _tracked: Dictionary = {}
var _scan_timer: float = 0.0
var _pixel_texture: Texture2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pixel_texture = _make_pixel_texture()

func _process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.35
		_scan_for_enemies()
	_cleanup_dead_refs()

func _scan_for_enemies() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var pending: Array[Node] = [scene]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		var children: Array[Node] = node.get_children()
		for child in children:
			pending.append(child)
		if _looks_like_enemy(node):
			_bind_enemy(node)

func _looks_like_enemy(node: Node) -> bool:
	if not (node is Node2D):
		return false
	if String(node.name).begins_with("V45"):
		return false
	if node.has_signal("health_changed") and node.has_signal("died"):
		return true
	var script: Script = node.get_script()
	if script != null:
		var p: String = String(script.resource_path).to_lower()
		return p.find("/enemy/enemy.gd") >= 0
	return false

func _bind_enemy(enemy: Node) -> void:
	var id: int = enemy.get_instance_id()
	if _tracked.has(id):
		return

	var current: float = _read_float_property(enemy, "health", 0.0)
	var maximum: float = _read_max_health(enemy, current)
	var ui: Node2D = _create_enemy_ui(enemy, current, maximum)

	_tracked[id] = {
		"enemy": weakref(enemy),
		"ui": weakref(ui),
		"last_health": current,
		"max_health": maximum
	}

	if enemy.has_signal("health_changed"):
		enemy.health_changed.connect(_on_health_changed.bind(id))
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(id))

func _on_health_changed(current: float, maximum: float, id: int) -> void:
	if not _tracked.has(id):
		return
	var data: Dictionary = _tracked[id]
	var previous: float = float(data.get("last_health", current))
	data["last_health"] = current
	data["max_health"] = maximum
	_tracked[id] = data

	var enemy_ref: WeakRef = data.get("enemy")
	var ui_ref: WeakRef = data.get("ui")
	var enemy: Node = enemy_ref.get_ref() if enemy_ref != null else null
	var ui: Node = ui_ref.get_ref() if ui_ref != null else null
	if enemy == null:
		return

	_update_bar(ui, current, maximum)

	var damage: float = maxf(0.0, previous - current)
	if damage > 0.0:
		_spawn_damage_number(enemy, damage)
		_flash_enemy(enemy)

func _on_enemy_died(enemy_node: Node, _killer: Node, id: int) -> void:
	if enemy_node is Node2D:
		_spawn_death_burst(enemy_node)
	if _tracked.has(id):
		_tracked.erase(id)

func _create_enemy_ui(enemy: Node, current: float, maximum: float) -> Node2D:
	var existing: Node = enemy.get_node_or_null("V45CombatUI")
	if existing is Node2D:
		_update_bar(existing, current, maximum)
		return existing

	var ui := Node2D.new()
	ui.name = "V45CombatUI"
	ui.position = Vector2(0, -38)
	ui.z_index = 80
	enemy.add_child(ui)

	var back := ColorRect.new()
	back.name = "HPBack"
	back.position = Vector2(-25, 0)
	back.size = Vector2(50, 6)
	back.color = Color(0.08, 0.06, 0.08, 0.92)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(back)

	var border := ColorRect.new()
	border.name = "HPBorder"
	border.position = Vector2(-24, 1)
	border.size = Vector2(48, 4)
	border.color = Color(0.28, 0.16, 0.13, 1.0)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(border)

	var fill := ColorRect.new()
	fill.name = "HPFill"
	fill.position = Vector2(-23, 2)
	fill.size = Vector2(46, 2)
	fill.color = Color(0.88, 0.16, 0.08, 1.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fill)

	var marker := ColorRect.new()
	marker.name = "HPHighlight"
	marker.position = Vector2(-23, 2)
	marker.size = Vector2(46, 1)
	marker.color = Color(1.0, 0.55, 0.25, 0.72)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(marker)

	_update_bar(ui, current, maximum)
	return ui

func _update_bar(ui: Node, current: float, maximum: float) -> void:
	if ui == null or not is_instance_valid(ui):
		return
	var ratio: float = 0.0
	if maximum > 0.0:
		ratio = clampf(current / maximum, 0.0, 1.0)

	var fill: ColorRect = ui.get_node_or_null("HPFill") as ColorRect
	var marker: ColorRect = ui.get_node_or_null("HPHighlight") as ColorRect
	if fill != null:
		fill.size.x = 46.0 * ratio
	if marker != null:
		marker.size.x = 46.0 * ratio
	ui.visible = maximum > 0.0 and current > 0.0

func _spawn_damage_number(enemy: Node, damage: float) -> void:
	if not (enemy is Node2D):
		return
	var label := Label.new()
	label.name = "V45Damage"
	label.text = str(int(round(damage)))
	label.position = Vector2(-8, -50)
	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.24, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.12, 0.02, 0.01, 0.92))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	enemy.add_child(label)

	var drift: float = -5.0 if (Time.get_ticks_msec() / 120) % 2 == 0 else 5.0
	var tween: Tween = enemy.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(drift, -24), 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.55)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func _flash_enemy(enemy: Node) -> void:
	var visual: CanvasItem = _find_visual_item(enemy)
	if visual == null:
		return

	if visual.has_meta("v45_flash_tween"):
		var old_tween: Variant = visual.get_meta("v45_flash_tween")
		if old_tween is Tween and old_tween.is_valid():
			old_tween.kill()

	var original: Color = visual.modulate
	visual.modulate = Color(1.35, 0.46, 0.28, original.a)
	var tween: Tween = enemy.create_tween()
	visual.set_meta("v45_flash_tween", tween)
	tween.tween_property(visual, "modulate", original, 0.13)

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
		if node is Sprite2D or node is AnimatedSprite2D or node is Polygon2D:
			return node as CanvasItem
		var children: Array[Node] = node.get_children()
		for child in children:
			if not String(child.name).begins_with("V45"):
				pending.append(child)
	return null

func _spawn_death_burst(enemy: Node2D) -> void:
	var parent: Node = enemy.get_parent()
	if parent == null:
		return

	var burst := CPUParticles2D.new()
	burst.name = "V45DeathBurst"
	burst.texture = _pixel_texture
	burst.position = enemy.position + Vector2(0, -8)
	burst.z_index = 95
	burst.amount = 28
	burst.lifetime = 0.65
	burst.one_shot = true
	burst.explosiveness = 0.92
	burst.local_coords = false
	burst.direction = Vector2(0, -1)
	burst.spread = 180.0
	burst.initial_velocity_min = 28.0
	burst.initial_velocity_max = 70.0
	burst.gravity = Vector2(0, 82)
	burst.scale_amount_min = 0.8
	burst.scale_amount_max = 1.6
	burst.color = Color(1.0, 0.28, 0.04, 0.95)
	parent.add_child(burst)
	burst.emitting = true

	var timer: SceneTreeTimer = get_tree().create_timer(1.2)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(burst):
			burst.queue_free()
	)

func _read_float_property(node: Object, property_name: String, fallback: float) -> float:
	for info in node.get_property_list():
		if String(info.get("name", "")) == property_name:
			return float(node.get(property_name))
	return fallback

func _read_max_health(enemy: Node, fallback: float) -> float:
	var stats: Variant = null
	for info in enemy.get_property_list():
		if String(info.get("name", "")) == "stats":
			stats = enemy.get("stats")
			break
	if stats != null:
		for info in stats.get_property_list():
			if String(info.get("name", "")) == "max_health":
				return maxf(0.0, float(stats.get("max_health")))
	return maxf(fallback, 0.0)

func _cleanup_dead_refs() -> void:
	var to_remove: Array[int] = []
	for id in _tracked.keys():
		var data: Dictionary = _tracked[id]
		var enemy_ref: WeakRef = data.get("enemy")
		if enemy_ref == null or enemy_ref.get_ref() == null:
			to_remove.append(int(id))
	for id in to_remove:
		_tracked.erase(id)

func _make_pixel_texture() -> Texture2D:
	var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.set_pixel(1, 0, Color.WHITE)
	img.set_pixel(0, 1, Color.WHITE)
	img.set_pixel(1, 1, Color.WHITE)
	img.set_pixel(2, 1, Color.WHITE)
	img.set_pixel(1, 2, Color.WHITE)
	return ImageTexture.create_from_image(img)
