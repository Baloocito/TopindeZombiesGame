extends Node
class_name JefesMundo
# ==========================================================
# JEFES: barra de vida, avisos en el suelo y zonas tóxicas
# ==========================================================
# Vive como hijo de Mundo con el nombre fijo "Jefes", así sus RPC tienen la
# misma ruta en todas las pantallas. La IA de los jefes corre solo en el
# servidor y usa estas funciones para que todos vean lo mismo:
#   - telegrafo_en_red: el círculo o la franja roja que avisa un ataque.
#   - zona_en_red: suelo contaminado (verde) que hace daño mientras dura.
#   - barra de vida del jefe arriba de la pantalla.

const COLOR_AVISO := Color(1.0, 0.15, 0.1)
const COLOR_TOXICO := Color(0.35, 1.0, 0.2)

var m: Node  # el nodo Mundo
var _barra: ProgressBar
var _lbl_nombre: Label
var _lbl_estado: Label
var _panel: Control
var _sucio := false
var _t_barra := 0.0
var _zonas: Array = []  # servidor: {pos, radio, activa_en, termina_en, t_tick}
var _t_zonas := 0.0
var _textos_t: Dictionary = {}  # limitador de textos flotantes por clave

# ----------------------------------------------------------
# BARRA DE VIDA DEL JEFE
# ----------------------------------------------------------
func _crear_barra():
	if is_instance_valid(_panel): return
	var ui: Node = m.get_node("InterfazUI")
	_panel = VBoxContainer.new()
	_panel.name = "BarraJefe"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.custom_minimum_size = Vector2(520, 0)
	_panel.position = Vector2(-260, 58)
	_panel.add_theme_constant_override("separation", 2)
	_lbl_nombre = Label.new()
	_lbl_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_nombre.add_theme_font_size_override("font_size", 22)
	_lbl_nombre.add_theme_color_override("font_color", Color(1, 0.85, 0.85))
	_lbl_nombre.add_theme_color_override("font_outline_color", Color.BLACK)
	_lbl_nombre.add_theme_constant_override("outline_size", 6)
	_panel.add_child(_lbl_nombre)
	_barra = ProgressBar.new()
	_barra.theme_type_variation = "BarraVida"
	_barra.show_percentage = false
	_barra.custom_minimum_size = Vector2(520, 16)
	_barra.max_value = 1.0
	_barra.step = 0.0
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_barra)
	_lbl_estado = Label.new()
	_lbl_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_estado.add_theme_font_size_override("font_size", 16)
	_lbl_estado.add_theme_color_override("font_color", Color(0.65, 0.95, 1.0))
	_lbl_estado.add_theme_color_override("font_outline_color", Color.BLACK)
	_lbl_estado.add_theme_constant_override("outline_size", 5)
	_panel.add_child(_lbl_estado)
	ui.add_child(_panel)
	_panel.visible = false

@rpc("authority", "call_local", "unreliable_ordered")
func barra_en_red(nombre: String, fraccion: float, estado: String, visible_: bool):
	_crear_barra()
	_panel.visible = visible_
	_lbl_nombre.text = nombre
	_barra.value = clampf(fraccion, 0.0, 1.0)
	_lbl_estado.text = estado
	_lbl_estado.visible = estado != ""

func marcar_barra():
	_sucio = true

func _process(delta: float) -> void:
	var peer := multiplayer.multiplayer_peer
	if not peer or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED or not multiplayer.is_server(): return
	_t_barra -= delta
	if _sucio and _t_barra <= 0.0:
		_t_barra = 0.12
		_sucio = false
		_enviar_barra()
	_procesar_zonas(delta)

func _enviar_barra():
	var jefes := get_tree().get_nodes_in_group("jefes")
	var vida := 0.0
	var maximo := 0.0
	var nombre := ""
	var estado := ""
	var tipos := {}
	for j in jefes:
		if not is_instance_valid(j) or j.esta_muerto: continue
		vida += maxf(0.0, j.salud_actual)
		maximo += j.salud_maxima
		tipos[j.tipo_zombie] = true
		if j.ia and j.ia.has_method("texto_estado") and estado == "":
			estado = j.ia.texto_estado()
		if nombre == "": nombre = Balance.nombre_enemigo(j.tipo_zombie)
	if tipos.has("guardian") or tipos.has("acechador"): nombre = "El Enjambre"
	barra_en_red.rpc(nombre, vida / maximo if maximo > 0.0 else 0.0, estado, maximo > 0.0)

# El Enjambre cuenta como un solo jefe: la barra suma a sus cuatro miembros.
# Al morir el último, la barra se oculta.
func jefe_murio():
	_sucio = true
	_t_barra = 0.0

# ----------------------------------------------------------
# AVISOS EN EL SUELO (todas las pantallas)
# ----------------------------------------------------------
# forma 0 = círculo (tam.x = radio) centrado en pos.
# forma 1 = franja que nace en pos y avanza hacia rot_y (tam = ancho, largo).
@rpc("authority", "call_local", "reliable")
func telegrafo_en_red(forma: int, pos: Vector3, rot_y: float, tam: Vector2, duracion: float):
	var base := _malla_suelo(forma, tam, COLOR_AVISO, 0.22)
	var relleno := _malla_suelo(forma, tam, COLOR_AVISO, 0.5)
	var raiz := Node3D.new()
	_efectos().add_child(raiz)
	raiz.global_position = Vector3(pos.x, 0.06, pos.z)
	raiz.rotation.y = rot_y
	raiz.add_child(base)
	raiz.add_child(relleno)
	relleno.position.y = 0.01
	var t := raiz.create_tween()
	if forma == 0:
		relleno.scale = Vector3(0.05, 1, 0.05)
		t.tween_property(relleno, "scale", Vector3.ONE, duracion)
	else:
		relleno.scale = Vector3(1, 1, 0.02)
		t.tween_property(relleno, "scale", Vector3.ONE, duracion)
	# Destello blanco en el momento del golpe.
	var mat_relleno: StandardMaterial3D = relleno.get_meta("mat")
	t.tween_callback(func(): mat_relleno.albedo_color = Color(1, 1, 1, 0.8))
	t.tween_property(raiz, "scale", Vector3(1.08, 1, 1.08), 0.12)
	t.tween_callback(raiz.queue_free)

# Devuelve un Node3D plano sobre el suelo. El círculo está centrado en su
# origen; la franja nace en el origen y avanza hacia -Z, así al escalar el
# eje Z crece desde el jefe hacia adelante. El material queda en meta "mat".
func _malla_suelo(forma: int, tam: Vector2, color: Color, alfa: float) -> Node3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alfa)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false  # los personajes se ven encima del aviso
	mat.render_priority = 5
	var mi := MeshInstance3D.new()
	mi.material_override = mat
	if forma == 0:
		var c := CylinderMesh.new()
		c.top_radius = tam.x
		c.bottom_radius = tam.x
		c.height = 0.02
		c.radial_segments = 40
		mi.mesh = c
		mi.set_meta("mat", mat)
		return mi
	var b := BoxMesh.new()
	b.size = Vector3(tam.x, 0.02, tam.y)
	mi.mesh = b
	mi.position = Vector3(0, 0, -tam.y * 0.5)
	var pivote := Node3D.new()
	pivote.add_child(mi)
	pivote.set_meta("mat", mat)
	return pivote

# Zona contaminada: aviso verde tenue durante `aviso` segundos y luego suelo
# tóxico durante `duracion`. El daño lo calcula el servidor.
@rpc("authority", "call_local", "reliable")
func zona_en_red(pos: Vector3, radio: float, aviso: float, duracion: float):
	var mi := _malla_suelo(0, Vector2(radio, 0), COLOR_TOXICO, 0.15)
	_efectos().add_child(mi)
	mi.global_position = Vector3(pos.x, 0.05, pos.z)
	var mat: StandardMaterial3D = mi.get_meta("mat")
	var t := mi.create_tween()
	t.tween_property(mat, "albedo_color:a", 0.25, aviso * 0.5)
	t.tween_property(mat, "albedo_color:a", 0.12, aviso * 0.5)
	t.tween_callback(func(): mat.albedo_color = Color(COLOR_TOXICO.r, COLOR_TOXICO.g, COLOR_TOXICO.b, 0.5))
	t.tween_interval(maxf(0.0, duracion - 0.4))
	t.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	t.tween_callback(mi.queue_free)

func _efectos() -> Node:
	var e := m.get_node_or_null("Efectos")
	if not e:
		e = Node3D.new()
		e.name = "Efectos"
		m.add_child(e)
	return e

@rpc("authority", "call_local", "unreliable")
func texto_en_red(pos: Vector3, texto: String, color: Color):
	EstiloUI.texto_flotante(pos, texto, color)

# Texto flotante desde el servidor, como mucho uno cada `cada` segundos por clave.
func texto_limitado(clave: String, pos: Vector3, texto: String, color: Color, cada: float = 0.6):
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora - float(_textos_t.get(clave, -100.0)) < cada: return
	_textos_t[clave] = ahora
	texto_en_red.rpc(pos, texto, color)

# ----------------------------------------------------------
# AYUDAS PARA LA IA (solo servidor)
# ----------------------------------------------------------
func jugadores_vivos() -> Array:
	var r: Array = []
	for j in get_tree().get_nodes_in_group("jugador"):
		if is_instance_valid(j) and j.salud_actual > 0 and not j.esta_caido:
			r.append(j)
	return r

func danar_jugadores_en_radio(pos: Vector3, radio: float, dano: int) -> int:
	var golpeados := 0
	for j in jugadores_vivos():
		var d := Vector2(j.global_position.x - pos.x, j.global_position.z - pos.z).length()
		if d <= radio:
			j.recibir_dano_en_red.rpc(dano)
			golpeados += 1
	return golpeados

func danar_estructuras_en_radio(pos: Vector3, radio: float, dano: int):
	for e in get_tree().get_nodes_in_group("barricadas"):
		if is_instance_valid(e) and e.global_position.distance_to(pos) <= radio and e.has_method("recibir_dano"):
			e.recibir_dano(dano)

# Invoca enemigos que cuentan para terminar la noche.
func invocar(tipo: String, posicion: Vector3) -> Node:
	var gen = m.get_node("GeneradorZombies")
	var z = gen.crear_enemigo(tipo, posicion + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)))
	if z and tipo != "nodo":
		m.zombies_vivos += 1
	return z

func puntos_de_aparicion() -> Array:
	var r: Array = []
	for p in m.get_node("GeneradorZombies").puntos_de_aparicion: r.append(p.global_position)
	return r

func agregar_zona(pos: Vector3, radio: float, aviso: float, duracion: float, dano_por_tick: int):
	var ahora := Time.get_ticks_msec() / 1000.0
	_zonas.append({"pos": pos, "radio": radio, "activa_en": ahora + aviso, "termina_en": ahora + aviso + duracion, "dano": dano_por_tick})
	zona_en_red.rpc(pos, radio, aviso, duracion)

func limpiar_zonas():
	_zonas.clear()

func _procesar_zonas(delta: float):
	if _zonas.is_empty(): return
	_t_zonas -= delta
	if _t_zonas > 0.0: return
	_t_zonas = 0.5
	var ahora := Time.get_ticks_msec() / 1000.0
	for z in _zonas.duplicate():
		if ahora >= z.termina_en:
			_zonas.erase(z)
		elif ahora >= z.activa_en:
			danar_jugadores_en_radio(z.pos, z.radio, z.dano)
