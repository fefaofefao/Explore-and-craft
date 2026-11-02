class_name SkyEnv
extends Node3D
## Céu procedural, sol/lua, névoa e ciclo dia/noite por bioma.

var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var biome: Dictionary
var quality: int = 1
var grass_mats: Array = []
var grass_light := 1.0
var clouds: MeshInstance3D
var cloud_mat: ShaderMaterial

var _sky_top: Color
var _sky_hor: Color
var _fog: Color
var _sun_col: Color
var _amb: Color
const NIGHT_TOP := Color("#0b1530")
const NIGHT_HOR := Color("#2a3a64")
const DUSK_HOR := Color("#ff9a6a")


func setup(p_biome: Dictionary, p_quality: int) -> void:
	biome = p_biome
	quality = p_quality
	_sky_top = Color(biome["sky_top"])
	_sky_hor = Color(biome["sky_horizon"])
	_fog = Color(biome["fog"]).lerp(Color(biome["sky_horizon"]), 0.35)
	_sun_col = Color(biome["sun"])
	_amb = Color(biome["ambient"])
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = _sky_top
	sky_mat.sky_horizon_color = _sky_hor
	sky_mat.ground_horizon_color = _sky_hor
	sky_mat.ground_bottom_color = _fog.darkened(0.4)
	sky_mat.sun_angle_max = 30.0
	sky_mat.sky_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _amb
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.85
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = _fog
	env.fog_density = float(biome["fog_density"]) * 0.45
	env.fog_sky_affect = 0.3
	env.fog_aerial_perspective = 0.0
	env.glow_enabled = quality >= 2
	env.glow_intensity = 0.35
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.06
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = _sun_col
	sun.light_energy = 1.25
	sun.shadow_enabled = quality >= 1
	sun.shadow_bias = 0.09
	sun.shadow_normal_bias = 2.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 50.0 if quality < 2 else 75.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_blur = 1.5
	sun.light_angular_distance = 0.6
	add_child(sun)
	# nuvens
	clouds = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 220.0
	sph.height = 440.0
	sph.radial_segments = 24
	sph.rings = 12
	clouds.mesh = sph
	cloud_mat = ShaderMaterial.new()
	cloud_mat.shader = load("res://assets/shaders/clouds.gdshader")
	cloud_mat.set_shader_parameter("noise_tex", load("res://assets/textures/noise.png"))
	cloud_mat.set_shader_parameter("coverage", 0.55 if biome.get("particles", "") != "rain" else 0.38)
	clouds.material_override = cloud_mat
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(clouds)
	moon = DirectionalLight3D.new()
	moon.light_color = Color("#8aa8ff")
	moon.light_energy = 0.0
	moon.shadow_enabled = false
	add_child(moon)


func update_time(day_time: float) -> void:
	## day_time 0..1 — 0.25 nascer, 0.5 meio-dia, 0.75 pôr do sol.
	var sf := SurvivalLogic.sun_factor(day_time)
	var ang := (day_time - 0.25) * TAU  # 0 no nascer, PI no pôr
	sun.rotation = Vector3(-clampf(sin(ang), 0.05, 1.0) * 1.2 - 0.15, -0.6 + cos(ang) * 0.9, 0.0)
	sun.light_energy = lerpf(0.0, 1.05, sf)
	sun.visible = sf > 0.02
	moon.rotation = Vector3(-0.9, 0.4 + day_time, 0.0)
	moon.light_energy = lerpf(0.5, 0.0, sf)
	# crepúsculo: horizonte alaranjado perto de 0.25 e 0.75
	var dusk := maxf(0.0, 1.0 - absf(day_time - 0.25) * 14.0) + maxf(0.0, 1.0 - absf(day_time - 0.75) * 14.0)
	dusk = clampf(dusk, 0.0, 1.0) * 0.7
	var top := NIGHT_TOP.lerp(_sky_top, sf)
	var hor := NIGHT_HOR.lerp(_sky_hor, sf).lerp(DUSK_HOR, dusk)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor
	env.fog_light_color = _fog.darkened(0.75 * (1.0 - sf)).lerp(DUSK_HOR, dusk * 0.4)
	env.ambient_light_color = _amb.darkened(0.55 * (1.0 - sf)).lerp(Color("#5a6aa8"), (1.0 - sf) * 0.35)
	env.ambient_light_energy = lerpf(0.45, 0.55, sf)
	sun.light_color = _sun_col.lerp(Color("#ffb070"), dusk)
	grass_light = lerpf(0.3, 1.32, sf)
	if cloud_mat != null:
		cloud_mat.set_shader_parameter("light", lerpf(0.18, 1.0, sf))
		cloud_mat.set_shader_parameter("cloud_color", Color.WHITE.lerp(Color("#ffc890"), dusk))
	for gm in grass_mats:
		(gm as ShaderMaterial).set_shader_parameter("light_mult", grass_light)


func follow(cam_pos: Vector3) -> void:
	if clouds != null:
		clouds.global_position = cam_pos
