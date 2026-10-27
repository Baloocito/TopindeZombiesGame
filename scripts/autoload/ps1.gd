extends Node
# ==========================================================
# ESTILO PS1 (autoload "PS1")
# ==========================================================
# Le da al juego el aspecto de la primera PlayStation sin tocar cada modelo:
# - Cada MeshInstance3D que entra a la escena pasa sus StandardMaterial3D
#   opacos al material de assets/ps1/ps1.gdshader (temblor de vértices,
#   texturas afines, luz por vértice). Los transparentes y los "sin luz"
#   (avisos, hologramas, efectos) se dejan igual.
# - En Mundo pone el filtro de pantalla (píxeles grandes + 32 colores con
#   tramado), la niebla y las sombras de mancha bajo personajes y zombies.
# - Se puede apagar en Pausa > Opciones (se guarda en user://ajustes.cfg).
# Funciona igual con los modelos que agreguemos después (packs low-poly).

const SHADER := preload("res://assets/ps1/ps1.gdshader")
const SHADER_DOBLE := preload("res://assets/ps1/ps1_doble_cara.gdshader")
const SHADER_PANTALLA := preload("res://assets/ps1/ps1_pantalla.gdshader")
const RUTA_AJUSTES := "user://ajustes.cfg"
const LINEAS := 270.0             # alto de la imagen virtual
const ESCALA_3D := 0.6            # el 3D se dibuja a menor resolución (rinde más en teléfonos)

var activo := true
# Distancia de la cámara: "lejos", "normal" o "cerca" (ver camera_3d.gd).
var zoom_camara := "normal"
var _noche := false
var _cache: Dictionary = {}       # material original -> ShaderMaterial PS1
var _filtro: CanvasLayer
var _env: Environment
var _luz: DirectionalLight3D
var _sombra_malla: PlaneMesh
var _sombra_mat: StandardMaterial3D

func _ready():
	var cfg := ConfigFile.new()
	zoom_camara = "cerca" if DisplayServer.is_touchscreen_available() else "normal"
	if cfg.load(RUTA_AJUSTES) == OK:
		activo = bool(cfg.get_value("video", "ps1", true))
		zoom_camara = str(cfg.get_value("video", "zoom", zoom_camara))
	_actualizar_resolucion()
	get_tree().root.size_changed.connect(_actualizar_resolucion)
	get_tree().node_added.connect(_al_agregar_nodo)
	_aplicar_viewport()

func alternar(valor: bool):
	activo = valor
	var cfg := ConfigFile.new()
	cfg.load(RUTA_AJUSTES)
	cfg.set_value("video", "ps1", activo)
	cfg.save(RUTA_AJUSTES)
	_aplicar_viewport()
	var escena := get_tree().current_scene
	if not escena: return
	for n in escena.find_children("*", "MeshInstance3D", true, false):
		if activo: convertir(n)
		else: restaurar(n)
	if is_instance_valid(_filtro): _filtro.visible = activo
	for s in get_tree().get_nodes_in_group("sombra_ps1"): s.visible = activo

func cambiar_zoom(valor: String):
	zoom_camara = valor
	var cfg := ConfigFile.new()
	cfg.load(RUTA_AJUSTES)
	cfg.set_value("video", "zoom", valor)
	cfg.save(RUTA_AJUSTES)
	poner_noche(_env, _luz, _noche)

func _aplicar_viewport():
	var vp := get_tree().root
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = ESCALA_3D if activo else 1.0

# La grilla del temblor sigue la forma de la pantalla.
func _actualizar_resolucion():
	var tam := get_tree().root.get_visible_rect().size
	var aspecto := tam.x / maxf(1.0, tam.y)
	RenderingServer.global_shader_parameter_set("ps1_resolucion", Vector2(floor(LINEAS * aspecto), LINEAS))

func _al_agregar_nodo(n: Node):
	if n is MeshInstance3D:
		if activo: convertir.call_deferred(n)
	elif n is CharacterBody3D and (n.is_in_group("jugador") or n.is_in_group("enemigos")):
		_agregar_sombra.call_deferred(n)
	elif n.name == "Mundo" and n is Node3D:
		_preparar_mundo.call_deferred(n)

# ----------------------------------------------------------
# MATERIALES
# ----------------------------------------------------------
func _convertible(m: Material) -> bool:
	if not m is BaseMaterial3D: return false
	var b := m as BaseMaterial3D
	return b.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
		and b.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED \
		and not b.no_depth_test

func _version_ps1(m: BaseMaterial3D) -> ShaderMaterial:
	if _cache.has(m): return _cache[m]
	var s := ShaderMaterial.new()
	s.shader = SHADER_DOBLE if m.cull_mode == BaseMaterial3D.CULL_DISABLED else SHADER
	s.set_shader_parameter("albedo", m.albedo_color)
	if m.albedo_texture:
		s.set_shader_parameter("textura", m.albedo_texture)
		s.set_shader_parameter("usar_textura", true)
	s.set_shader_parameter("usar_color_vertice", m.vertex_color_use_as_albedo)
	s.set_shader_parameter("uv_escala", m.uv1_scale)
	s.set_shader_parameter("uv_desfase", m.uv1_offset)
	if m.emission_enabled:
		s.set_shader_parameter("emision", m.emission)
		s.set_shader_parameter("emision_energia", m.emission_energy_multiplier)
	_cache[m] = s
	return s

# Sin tipo en el parámetro: llega diferido y el nodo pudo liberarse antes.
func convertir(n):
	if not is_instance_valid(n) or not activo or n.is_in_group("sin_ps1"): return
	if n.material_override:
		if _convertible(n.material_override):
			n.set_meta("ps1_override", n.material_override)
			n.material_override = _version_ps1(n.material_override)
		return
	if not n.mesh: return
	for i in n.mesh.get_surface_count():
		var m: Material = n.get_surface_override_material(i)
		if not m: m = n.mesh.surface_get_material(i)
		if m and _convertible(m):
			n.set_meta("ps1_sup_%d" % i, n.get_surface_override_material(i))
			n.set_surface_override_material(i, _version_ps1(m))

func restaurar(n: MeshInstance3D):
	if n.has_meta("ps1_override"):
		n.material_override = n.get_meta("ps1_override")
		n.remove_meta("ps1_override")
	if not n.mesh: return
	for i in n.mesh.get_surface_count():
		var k := "ps1_sup_%d" % i
		if n.has_meta(k):
			n.set_surface_override_material(i, n.get_meta(k))
			n.remove_meta(k)

# Tinte de un modelo entero (zombie.gd lo usa para el color por tipo).
func aplicar_tinte(raiz: Node, color: Color, intensidad: float):
	for m in raiz.find_children("*", "MeshInstance3D", true, false):
		(m as GeometryInstance3D).set_instance_shader_parameter("ps1_tinte", Color(color.r, color.g, color.b, intensidad))

# ----------------------------------------------------------
# SOMBRA DE MANCHA (como en los juegos de la época)
# ----------------------------------------------------------
func _agregar_sombra(cuerpo):
	if not is_instance_valid(cuerpo) or cuerpo.has_node("SombraPS1"): return
	if "tipo_zombie" in cuerpo and cuerpo.tipo_zombie == "nodo": return
	if not _sombra_malla:
		_sombra_malla = PlaneMesh.new()
		_sombra_malla.size = Vector2(1.3, 1.3)
		var grad := Gradient.new()
		grad.set_color(0, Color(0, 0, 0, 0.55))
		grad.set_color(1, Color(0, 0, 0, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 32
		tex.height = 32
		_sombra_mat = StandardMaterial3D.new()
		_sombra_mat.albedo_texture = tex
		_sombra_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_sombra_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_sombra_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_sombra_malla.material = _sombra_mat
	var s := MeshInstance3D.new()
	s.name = "SombraPS1"
	s.mesh = _sombra_malla
	s.position = Vector3(0, 0.04, 0)
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.add_to_group("sombra_ps1")
	s.add_to_group("sin_ps1")
	s.visible = activo
	cuerpo.add_child(s)

# ----------------------------------------------------------
# MUNDO: filtro de pantalla, niebla y suelo
# ----------------------------------------------------------
func _preparar_mundo(mundo):
	if not is_instance_valid(mundo): return
	# Filtro de pantalla, debajo de la interfaz (que está en la capa 1).
	_filtro = CanvasLayer.new()
	_filtro.name = "FiltroPS1"
	_filtro.layer = 0
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_PANTALLA
	mat.set_shader_parameter("lineas", LINEAS)
	rect.material = mat
	_filtro.add_child(rect)
	_filtro.visible = activo
	mundo.add_child(_filtro)
	_env = crear_ambiente(mundo)
	_luz = mundo.get_node_or_null("DirectionalLight3D")
	if _luz: _luz.light_color = Color("#fff1d6")
	_texturizar_suelo(mundo)

# Suelo de tierra con textura de 128 px repetida cada ~8 m, y subdividido para
# que el mapeo afín deforme poco (la PS1 hacía lo mismo con los suelos).
func _texturizar_suelo(mundo: Node3D):
	var suelo := mundo.get_node_or_null("NavigationRegion3D/Suelo") as MeshInstance3D
	if not suelo or not suelo.mesh is PlaneMesh: return
	var plano := (suelo.mesh as PlaneMesh).duplicate() as PlaneMesh
	plano.subdivide_width = 24
	plano.subdivide_depth = 24
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/ps1/suelo_tierra.png")
	mat.uv1_scale = Vector3(6, 6, 1)  # 128 px cada ~8 m
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	plano.material = mat
	suelo.mesh = plano
	if activo: convertir(suelo)

func poner_noche_mundo(noche: bool):
	poner_noche(_env, _luz, noche)

# Ambiente: niebla de profundidad oscura (oculta los bordes de la arena y
# da el tono de survival horror). De noche se cierra y se enfría.
func crear_ambiente(mundo: Node3D) -> Environment:
	var amb := WorldEnvironment.new()
	amb.name = "AmbientePS1"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2b2a28")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a8478")
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("#3a3833")
	env.fog_density = 1.0
	env.fog_depth_begin = 18.0
	env.fog_depth_end = 45.0
	env.fog_depth_curve = 1.2
	env.fog_sky_affect = 1.0
	amb.environment = env
	mundo.add_child(amb)
	return env

func poner_noche(env: Environment, luz: DirectionalLight3D, noche: bool):
	if not env: return
	var t := create_tween().set_parallel(true)
	var fondo := Color("#0d0f16") if noche else Color("#2b2a28")
	t.tween_property(env, "background_color", fondo, 2.0)
	t.tween_property(env, "fog_light_color", Color("#141824") if noche else Color("#3a3833"), 2.0)
	# La niebla empieza un poco detrás del jugador, según qué tan lejos esté la cámara.
	_noche = noche
	var d := float({"lejos": 18.0, "normal": 14.0, "cerca": 10.5}.get(zoom_camara, 14.0))
	t.tween_property(env, "fog_depth_begin", d + (0.0 if noche else 4.0), 2.0)
	t.tween_property(env, "fog_depth_end", d + (20.0 if noche else 28.0), 2.0)
	t.tween_property(env, "ambient_light_color", Color("#7a86a8") if noche else Color("#8a8478"), 2.0)
	t.tween_property(env, "ambient_light_energy", 0.8 if noche else 0.55, 2.0)
	if is_instance_valid(luz):
		t.tween_property(luz, "light_energy", 0.75 if noche else 1.0, 2.0)
		t.tween_property(luz, "light_color", Color("#9fb0d8") if noche else Color("#fff1d6"), 2.0)
