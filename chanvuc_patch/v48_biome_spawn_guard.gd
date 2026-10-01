extends Node

var _scene_id: int = 0
var _hoa_tich_refs: Array[WeakRef] = []
var _hud_refs: Array[WeakRef] = []
var _last_region_active: bool = false
var _region_entered_msec: int = 0
var _check_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_rescan_scene")

func _process(delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene != null and scene.get_instance_id() != _scene_id:
		call_deferred("_rescan_scene")

	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = 0.40

	var active: bool = _is_long_vuc_active()
	if active != _last_region_active:
		_last_region_active = active
		if active:
			_region_entered_msec = Time.get_ticks_msec()
		_apply_hud_visibility(active)

	_update_hoa_tich_state(active)

func _on_node_added(node: Node) -> void:
	if node == null:
		return
	if _is_hoa_tich(node):
		_register_hoa_tich(node)
	elif node is Label or node is RichTextLabel:
		_register_hud_node(node)

func _rescan_scene() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	_scene_id = scene.get_instance_id()
	_hoa_tich_refs.clear()
	_hud_refs.clear()

	var pending: Array[Node] = [scene]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if _is_hoa_tich(node):
			_register_hoa_tich(node)
			continue
		if node is Label or node is RichTextLabel:
			_register_hud_node(node)
		var children: Array[Node] = node.get_children()
		for child in children:
			pending.append(child)

	_last_region_active = _is_long_vuc_active()
	if _last_region_active:
		_region_entered_msec = Time.get_ticks_msec()
	_apply_hud_visibility(_last_region_active)
	_update_hoa_tich_state(_last_region_active)

func _register_hoa_tich(node: Node) -> void:
	for wr in _hoa_tich_refs:
		if wr.get_ref() == node:
			return
	_hoa_tich_refs.append(weakref(node))
	if not node.has_meta("v48_saved_process_mode"):
		node.set_meta("v48_saved_process_mode", node.process_mode)
	if node is CanvasItem and not node.has_meta("v48_saved_visible"):
		node.set_meta("v48_saved_visible", (node as CanvasItem).visible)
	_save_collision_state(node)

func _register_hud_node(node: Node) -> void:
	var text_value: String = ""
	if node is Label:
		text_value = (node as Label).text
	elif node is RichTextLabel:
		text_value = (node as RichTextLabel).text
	var normalized: String = text_value.to_lower()
	if normalized.find("hỏa tích") < 0 and normalized.find("hoa tich") < 0:
		return
	for wr in _hud_refs:
		if wr.get_ref() == node:
			return
	_hud_refs.append(weakref(node))

func _update_hoa_tich_state(region_active: bool) -> void:
	var player: Node2D = _get_player()
	var allow_activation: bool = false
	if region_active:
		var elapsed: int = Time.get_ticks_msec() - _region_entered_msec
		if elapsed >= 2200:
			allow_activation = true

	var alive_refs: Array[WeakRef] = []
	for wr in _hoa_tich_refs:
		var enemy: Node = wr.get_ref()
		if enemy == null:
			continue
		alive_refs.append(wr)

		var should_enable: bool = allow_activation
		if should_enable and player != null and enemy is Node2D:
			var distance: float = (enemy as Node2D).global_position.distance_to(player.global_position)
			if distance < 420.0:
				should_enable = false

		_set_enemy_enabled(enemy, should_enable)

	_hoa_tich_refs = alive_refs

func _set_enemy_enabled(enemy: Node, enabled: bool) -> void:
	if enabled:
		if enemy.has_meta("v48_saved_process_mode"):
			enemy.process_mode = int(enemy.get_meta("v48_saved_process_mode"))
		else:
			enemy.process_mode = Node.PROCESS_MODE_INHERIT
		if enemy is CanvasItem:
			(enemy as CanvasItem).visible = bool(enemy.get_meta("v48_saved_visible", true))
		_restore_collision_state(enemy)
	else:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		if enemy is CanvasItem:
			(enemy as CanvasItem).visible = false
		_disable_collisions(enemy)

func _save_collision_state(root: Node) -> void:
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is CollisionObject2D:
			var obj := node as CollisionObject2D
			if not obj.has_meta("v48_collision_layer"):
				obj.set_meta("v48_collision_layer", obj.collision_layer)
				obj.set_meta("v48_collision_mask", obj.collision_mask)
		var children: Array[Node] = node.get_children()
		for child in children:
			pending.append(child)

func _disable_collisions(root: Node) -> void:
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is CollisionObject2D:
			var obj := node as CollisionObject2D
			obj.collision_layer = 0
			obj.collision_mask = 0
		var children: Array[Node] = node.get_children()
		for child in children:
			pending.append(child)

func _restore_collision_state(root: Node) -> void:
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is CollisionObject2D:
			var obj := node as CollisionObject2D
			if obj.has_meta("v48_collision_layer"):
				obj.collision_layer = int(obj.get_meta("v48_collision_layer"))
				obj.collision_mask = int(obj.get_meta("v48_collision_mask"))
		var children: Array[Node] = node.get_children()
		for child in children:
			pending.append(child)

func _apply_hud_visibility(active: bool) -> void:
	var alive: Array[WeakRef] = []
	for wr in _hud_refs:
		var node: Node = wr.get_ref()
		if node == null:
			continue
		alive.append(wr)
		if node is CanvasItem:
			(node as CanvasItem).visible = active
	_hud_refs = alive

func _is_long_vuc_active() -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return false

	var scene_name: String = String(scene.name).to_lower()
	if _matches_long_vuc(scene_name):
		return true

	var candidates: Array[Node] = []
	for node in get_tree().root.get_children():
		if node != self:
			candidates.append(node)
	candidates.append(scene)

	var props: Array[String] = [
		"current_region_id", "active_region_id", "region_id",
		"current_region", "active_region",
		"current_biome", "biome_id"
	]

	for node in candidates:
		if node == null:
			continue
		for prop in props:
			if _has_property(node, prop):
				var value: Variant = node.get(prop)
				if _matches_long_vuc(String(value).to_lower()):
					return true

	var player: Node2D = _get_player()
	if player != null:
		for key in ["current_region_id", "region_id", "current_biome", "biome_id"]:
			if player.has_meta(key):
				if _matches_long_vuc(String(player.get_meta(key)).to_lower()):
					return true

	return false

func _matches_long_vuc(value: String) -> bool:
	return value.find("long_vuc") >= 0 or value.find("long vuc") >= 0 or value.find("long vực") >= 0

func _has_property(obj: Object, property_name: String) -> bool:
	for info in obj.get_property_list():
		if String(info.get("name", "")) == property_name:
			return true
	return false

func _get_player() -> Node2D:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	if players[0] is Node2D:
		return players[0] as Node2D
	return null

func _is_hoa_tich(node: Node) -> bool:
	if not (node is Node2D):
		return false
	var lower_name: String = String(node.name).to_lower()
	if lower_name.find("hoa_tich") >= 0 or lower_name.find("hoatich") >= 0:
		return true
	var script: Script = node.get_script()
	if script != null:
		var path: String = String(script.resource_path).to_lower()
		if path.find("hoa_tich") >= 0 or path.find("hoatich") >= 0:
			return true
	if _has_property(node, "stats"):
		var stats: Variant = node.get("stats")
		if stats != null:
			for key in ["display_name", "enemy_id", "id"]:
				if _has_property(stats, key):
					var value: String = String(stats.get(key)).to_lower()
					if value.find("hỏa tích") >= 0 or value.find("hoa_tich") >= 0 or value.find("hoa tich") >= 0:
						return true
	return false
