extends Button
class_name SimonButton

const FLAT_SHIMMER_SHADER := preload("res://shaders/flat_shimmer.gdshader")

@export var pad_name: String = ""
@export var base_color: Color = Color.WHITE
@export var lit_color: Color = Color.WHITE
@export var tone_freq: float = 440.0

var shader_material: ShaderMaterial = null
var _is_flat_shimmer := true
var _glow_tween: Tween = null

func _ready() -> void:
	_set_color(base_color)
	clear_shader_skin()
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

func _on_button_down() -> void:
	_set_glow(1.0)
	Sound.play_tone(tone_freq)

func _on_button_up() -> void:
	_tween_glow_out()

func refresh() -> void:
	_set_color(base_color)
	if _is_flat_shimmer and shader_material:
		shader_material.set_shader_parameter("base_color", base_color)
		shader_material.set_shader_parameter("lit_color", lit_color)

func flash(duration := 0.4, decay_rate := 3.2, volume := 0.5, play_sound := true) -> void:
	_set_glow(1.0)
	if play_sound:
		Sound.play_tone(tone_freq, 1.6, volume, decay_rate)
	await get_tree().create_timer(duration).timeout
	_tween_glow_out()

func set_shader_skin(shader: Shader, seed_offset: float) -> void:
	var mat := _material_for(shader)
	mat.set_shader_parameter("seed", seed_offset)
	_is_flat_shimmer = false
	shader_material = mat
	material = mat

# Not literally "no shader" anymore - installs the shared flat-palette
# shimmer, which is the default look for the 8 non-animated palettes.
func clear_shader_skin() -> void:
	var mat := _material_for(FLAT_SHIMMER_SHADER)
	mat.set_shader_parameter("seed", randf() * 10.0)
	mat.set_shader_parameter("base_color", base_color)
	mat.set_shader_parameter("lit_color", lit_color)
	_is_flat_shimmer = true
	shader_material = mat
	material = mat

# Reuses the existing material when it's already running the requested
# shader (the common case: re-applying the same palette/theme, or a fresh
# skin swap) instead of reallocating on every call; only allocates when
# actually switching to a different shader.
func _material_for(shader: Shader) -> ShaderMaterial:
	if shader_material and shader_material.shader == shader:
		return shader_material
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

func _set_glow(value: float) -> void:
	if _glow_tween:
		_glow_tween.kill()
		_glow_tween = null
	shader_material.set_shader_parameter("glow", value)

func _tween_glow_out() -> void:
	if _glow_tween:
		_glow_tween.kill()
	var t := create_tween()
	_glow_tween = t
	var mat := shader_material
	t.tween_method(func(v): mat.set_shader_parameter("glow", v), 1.0, 0.0, 0.3)

func _set_color(color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	# Tongue shape: rounded outer tip, narrower rounding at the base near the
	# resonator. Local (0,0) is the base (pivot), local +y extends to the tip.
	var tip_radius := size.x / 2.0
	var base_radius := size.x * 0.15
	sb.corner_radius_top_left = base_radius
	sb.corner_radius_top_right = base_radius
	sb.corner_radius_bottom_left = tip_radius
	sb.corner_radius_bottom_right = tip_radius
	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("hover", sb)
	add_theme_stylebox_override("pressed", sb)
	add_theme_stylebox_override("focus", sb)
	add_theme_stylebox_override("disabled", sb)
