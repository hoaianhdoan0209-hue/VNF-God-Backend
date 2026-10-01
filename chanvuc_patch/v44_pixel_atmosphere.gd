extends Node

var _scene_id := 0
var _world_modulate: CanvasModulate
var _player_light: PointLight2D
var _flicker_lights: Array = []
var _elapsed := 0.0
var _cycle_time := 48.0
var _light_texture: Texture2D
var _pixel_texture: Texture2D
var _liquid_shader: Shader

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_light_texture = _make_radial_texture(64)
	_pixel_texture = _make_pixel_texture()
	_liquid_shader = _make_liquid_shader()
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_install_for_current_scene")

func _process(delta: float) -> void:
	_elapsed += delta
	var scene := get_tree().current_scene
	if scene != null and scene.get_instance_id() != _scene_id:
		_install_for_current_scene()

	if is_instance_valid(_world_modulate):
		_cycle_time = fmod(_cycle_time + delta, 180.0)
		var phase := _cycle_time / 180.0
		var daylight: float = 0.5 + 0.5 * sin(phase * TAU - PI * 0.5)
		daylight = pow(clampf(daylight, 0.0, 1.0), 0.72)
		var night_color := Color(0.48, 0.56, 0.76, 1.0)
		var dusk_color := Color(0.82, 0.72, 0.80, 1.0)
		var day_color := Color(1.0, 1.0, 1.0, 1.0)
		var tint := night_color.lerp(dusk_color, minf(daylight * 2.0, 1.0))
		if daylight > 0.5:
			tint = dusk_color.lerp(day_color, (daylight - 0.5) * 2.0)
		_world_modulate.color = tint

		if is_instance_valid(_player_light):
			_player_light.energy = 0.10 + (1.0 - daylight) * 0.42

	for i in range(_flicker_lights.size()):
		var light = _flicker_lights[i]
		if is_instance_valid(light):
			var base := float(light.get_meta("v44_base_energy", 0.65))
			light.energy = base * (0.90 + 0.10 * sin(_elapsed * 11.0 + float(i) * 1.73))

func _install_for_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_scene_id = scene.get_instance_id()
	_flicker_lights.clear()

	var existing := scene.get_node_or_null("V44WorldModulate")
	if existing is CanvasModulate:
		_world_modulate = existing
	else:
		_world_modulate = CanvasModulate.new()
		_world_modulate.name = "V44WorldModulate"
		scene.add_child(_world_modulate)

	_decorate_tree(scene)
	_attach_player_fx()

func _on_node_added(node: Node) -> void:
	if node == null:
		return
	call_deferred("_decorate_node", node)
	call_deferred("_attach_player_fx")

func _decorate_tree(node: Node) -> void:
	_decorate_node(node)
	for child in node.get_children():
		_decorate_tree(child)

func _decorate_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var lower_name := String(node.name).to_lower()

	if _is_hoa_tich(node):
		_add_ember_fx(node)
		_add_warm_light(node, "V44HoaTichLight", 0.58, 1.25, Color(1.0, 0.31, 0.08, 1.0))
		return

	if lower_name.find("furnace") >= 0 or lower_name.find("lo_nung") >= 0 or lower_name.find("torch") >= 0:
		_add_warm_light(node, "V44WarmLight", 0.72, 1.10, Color(1.0, 0.58, 0.18, 1.0))
		_add_fire_fx(node)

	if node is Sprite2D:
		if lower_name.find("water") >= 0 or lower_name.find("nuoc") >= 0 or lower_name.find("lava") >= 0 or lower_name.find("dung_nham") >= 0:
			_add_liquid_shimmer(node)

func _attach_player_fx() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players[0]
	if not (player is Node2D):
		return

	if player.get_node_or_null("V44PlayerLight") == null:
		var light := PointLight2D.new()
		light.name = "V44PlayerLight"
		light.texture = _light_texture
		light.texture_scale = 2.4
		light.color = Color(1.0, 0.78, 0.52, 1.0)
		light.energy = 0.20
		light.position = Vector2(0, -8)
		player.add_child(light)
		_player_light = light
	else:
		_player_light = player.get_node("V44PlayerLight")

	if player.get_node_or_null("V44AmbientDust") == null:
		var dust := CPUParticles2D.new()
		dust.name = "V44AmbientDust"
		dust.texture = _pixel_texture
		dust.amount = 16
		dust.lifetime = 2.4
		dust.local_coords = false
		dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		dust.emission_rect_extents = Vector2(150, 90)
		dust.direction = Vector2(0, -1)
		dust.spread = 180.0
		dust.initial_velocity_min = 3.0
		dust.initial_velocity_max = 9.0
		dust.gravity = Vector2(0, -1.5)
		dust.color = Color(0.80, 0.88, 1.0, 0.22)
		dust.position = Vector2(0, -24)
		dust.z_index = 25
		player.add_child(dust)

func _is_hoa_tich(node: Node) -> bool:
	var lower_name := String(node.name).to_lower()
	if lower_name.find("hoa_tich") >= 0 or lower_name.find("hoatich") >= 0:
		return true
	var script = node.get_script()
	if script != null:
		var path := String(script.resource_path).to_lower()
		return path.find("hoa_tich") >= 0 or path.find("hoatich") >= 0
	return false

func _add_ember_fx(node: Node) -> void:
	if not (node is Node2D):
		return
	if node.get_node_or_null("V44Embers") != null:
		return
	var embers := CPUParticles2D.new()
	embers.name = "V44Embers"
	embers.texture = _pixel_texture
	embers.amount = 18
	embers.lifetime = 1.15
	embers.local_coords = false
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(26, 14)
	embers.direction = Vector2(0, -1)
	embers.spread = 48.0
	embers.initial_velocity_min = 14.0
	embers.initial_velocity_max = 30.0
	embers.gravity = Vector2(0, 12)
	embers.color = Color(1.0, 0.26, 0.03, 0.88)
	embers.position = Vector2(0, -8)
	embers.z_index = 35
	node.add_child(embers)

func _add_fire_fx(node: Node) -> void:
	if not (node is Node2D):
		return
	if node.get_node_or_null("V44FirePixels") != null:
		return
	var fire := CPUParticles2D.new()
	fire.name = "V44FirePixels"
	fire.texture = _pixel_texture
	fire.amount = 10
	fire.lifetime = 0.70
	fire.local_coords = false
	fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fire.emission_rect_extents = Vector2(8, 5)
	fire.direction = Vector2(0, -1)
	fire.spread = 26.0
	fire.initial_velocity_min = 9.0
	fire.initial_velocity_max = 22.0
	fire.gravity = Vector2(0, -4)
	fire.color = Color(1.0, 0.50, 0.08, 0.90)
	fire.position = Vector2(0, -8)
	fire.z_index = 32
	node.add_child(fire)

func _add_warm_light(node: Node, light_name: String, energy: float, scale: float, color: Color) -> void:
	if not (node is Node2D):
		return
	var existing := node.get_node_or_null(light_name)
	if existing is PointLight2D:
		if not _flicker_lights.has(existing):
			_flicker_lights.append(existing)
		return
	var light := PointLight2D.new()
	light.name = light_name
	light.texture = _light_texture
	light.texture_scale = scale
	light.color = color
	light.energy = energy
	light.set_meta("v44_base_energy", energy)
	node.add_child(light)
	_flicker_lights.append(light)

func _add_liquid_shimmer(sprite: Sprite2D) -> void:
	if sprite.has_meta("v44_liquid"):
		return
	var mat := ShaderMaterial.new()
	mat.shader = _liquid_shader
	sprite.material = mat
	sprite.set_meta("v44_liquid", true)

func _make_radial_texture(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(size - 1) * 0.5, float(size - 1) * 0.5)
	var max_d: float = maxf(center.x, 1.0)
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(float(x), float(y)).distance_to(center) / max_d
			var a: float = pow(maxf(0.0, 1.0 - d), 1.8)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
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

func _make_liquid_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

void fragment() {
	vec2 uv = UV;
	float wave = (sin(uv.x * 38.0 + TIME * 2.6) + sin(uv.x * 17.0 - TIME * 1.7)) * 0.0024;
	vec4 c = texture(TEXTURE, vec2(uv.x, clamp(uv.y + wave, 0.0, 1.0)));
	float glint = 0.95 + 0.05 * sin(TIME * 3.0 + uv.x * 25.0);
	COLOR = vec4(c.rgb * glint, c.a);
}
"""
	return shader
