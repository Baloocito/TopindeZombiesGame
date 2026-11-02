extends EstructuraBase

# ==========================================================
# 1. ESTADÍSTICAS Y ESTADO
# ==========================================================
@export_category("Configuración")

# --- SISTEMA DE COMBATE ---
var arma_equipada: ArmaData = null
var balas_cargadas: int = 0
var objetivo_actual: Node3D = null
var temporizador_disparo: float = 0.0
var enemigos_en_rango: Array[Node3D] = []

# --- INTELIGENCIA DE APUNTADO ---
var velocidad_giro: float = 12.0 # Qué tan rápido gira el "cuello" de la torreta
var velocidad_bala_estimada: float = 30.0 # ¡NUEVO! Ajusta esto a la velocidad real de tu bala
var alineado_para_disparar: bool = false

# --- REFERENCIAS ---
@onready var cabezal = $Cabezal
@onready var punto_disparo = $Cabezal/PuntoDisparo
@export var bala_escena: PackedScene

# ==========================================================
# 2. INICIALIZACIÓN Y LOOP PRINCIPAL
# ==========================================================
func _ready():
	super._ready()
	_poner_modelo()

# Modelo propio (assets/modelos/estructuras_kh/torreta.glb): las piezas de
# abajo quedan fijas como base y las de arriba pasan al Cabezal, que gira
# hacia el zombie (el frente del cabezal es su +Z, ver apuntar_a_objetivo).
const ANCHO_TORRETA := 1.8
const GIRO_TORRETA := 0.0   # giro del modelo para que su cañón mire al +Z del cabezal
func _poner_modelo():
	if not ModelosPSX.tiene_estructura("torreta"): return
	var base := get_node_or_null("Base") as MeshInstance3D
	var base_y := 0.0
	if base and base.mesh is BoxMesh: base_y = base.position.y - (base.mesh as BoxMesh).size.y * 0.5
	if base: base.visible = false
	var malla_cabezal := cabezal.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if malla_cabezal: malla_cabezal.visible = false
	var m := ModelosPSX.estructura("torreta", ANCHO_TORRETA, GIRO_TORRETA)
	m.position.y = base_y
	add_child(m)
	var alto := 0.0
	var piezas: Array = []
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var caja: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb() if mi.is_inside_tree() else AABB()
		piezas.append([mi, caja])
		alto = maxf(alto, caja.end.y - global_position.y)
	for p in piezas:
		var caja: AABB = p[1]
		if caja.position.y - global_position.y > alto * 0.33:
			var mi: MeshInstance3D = p[0]
			var t := mi.global_transform
			mi.get_parent().remove_child(mi)
			cabezal.add_child(mi)
			mi.global_transform = t

func _physics_process(delta):
	# --- FIX (revisión de código) ---
	# Antes esta función corría en TODOS los peers por igual: cada cliente
	# calculaba su propia puntería y disparaba sus propias balas locales,
	# que nunca hacían daño real (zombie.gd solo acepta daño del servidor).
	# Con el MultiplayerSynchronizer nuevo, el servidor es la autoridad y
	# replica salud_actual / balas_cargadas / Cabezal.rotation a todos.
	# Los clientes ahora solo VEN el resultado, no simulan la torreta.
	if not multiplayer.is_server(): return

	# 1. Mantenimiento del radar
	enemigos_en_rango = enemigos_en_rango.filter(func(enemigo): return is_instance_valid(enemigo) and enemigo.salud_actual > 0)

	# 2. Búsqueda inteligente
	if not is_instance_valid(objetivo_actual) or objetivo_actual.salud_actual <= 0:
		buscar_nuevo_objetivo()

	# 3. Lógica de Apuntado y Disparo Disciplinado
	if is_instance_valid(objetivo_actual) and arma_equipada and balas_cargadas > 0:
		apuntar_a_objetivo(delta)

		# ¡EL TRUCO MILITAR!: Solo dispara si el cañón ya está alineado con el zombie
		if alineado_para_disparar:
			temporizador_disparo += delta
			var tiempo_entre_balas = 1.0 / arma_equipada.cadencia
			if temporizador_disparo >= tiempo_entre_balas:
				disparar()
	else:
		temporizador_disparo = 0.0 # No guardamos la "carga" del disparo si perdemos el objetivo

# ==========================================================
# 3. CEREBRO DE PUNTERÍA (PREDICCIÓN)
# ==========================================================
func apuntar_a_objetivo(delta):
	# A. Puntería Predictiva (Leading)
	var distancia = global_position.distance_to(objetivo_actual.global_position)
	var tiempo_vuelo = distancia / velocidad_bala_estimada

	var pos_futura = objetivo_actual.global_position
	# Si el zombie se está moviendo, calculamos dónde estará cuando llegue la bala
	if "velocity" in objetivo_actual:
		pos_futura += (objetivo_actual.velocity * tiempo_vuelo)

	var pos_mirar = Vector3(pos_futura.x, cabezal.global_position.y, pos_futura.z)

	# B. Rotación suave y controlada
	var rotacion_actual = cabezal.rotation.y

	# Usamos un look_at instantáneo falso para saber a qué ángulo debemos llegar
	cabezal.look_at(pos_mirar, Vector3.UP)
	cabezal.rotate_y(PI) # Tu corrección de 180 grados
	var rotacion_deseada = cabezal.rotation.y

	# Restauramos el cabezal a donde estaba y lo movemos suavemente (lerp)
	cabezal.rotation.y = rotacion_actual
	cabezal.rotation.y = lerp_angle(cabezal.rotation.y, rotacion_deseada, velocidad_giro * delta)

	# C. Disciplina de gatillo: ¿Estamos apuntando directamente a la posición futura?
	# Permitimos un margen de error de 8 grados para empezar a soltar balas.
	var diferencia_angulo = abs(angle_difference(cabezal.rotation.y, rotacion_deseada))
	alineado_para_disparar = diferencia_angulo < deg_to_rad(8.0)

func disparar():
	temporizador_disparo = 0.0
	balas_cargadas -= 1

	if not bala_escena: return

	var dispersion_rad = deg_to_rad(arma_equipada.dispersion) if arma_equipada.dispersion > 0.0 else 0.0

	for i in range(arma_equipada.balas_por_disparo):
		var nueva_bala = bala_escena.instantiate()
		get_tree().current_scene.add_child(nueva_bala)
		nueva_bala.global_transform = punto_disparo.global_transform

		if dispersion_rad > 0.0:
			var angulo_desvio = randf_range(-dispersion_rad, dispersion_rad)
			nueva_bala.rotate_y(angulo_desvio)

		if "dano" in nueva_bala:
			nueva_bala.dano = arma_equipada.dano

# ==========================================================
# 4. SISTEMA DE RADAR Y SELECCIÓN DE OBJETIVOS
# ==========================================================
func _on_area_deteccion_body_entered(body):
	if body.is_in_group("enemigos"):
		enemigos_en_rango.append(body)

func _on_area_deteccion_body_exited(body):
	if body in enemigos_en_rango:
		enemigos_en_rango.erase(body)
		if objetivo_actual == body:
			objetivo_actual = null

func buscar_nuevo_objetivo():
	if enemigos_en_rango.is_empty():
		objetivo_actual = null
		return

	# ¡NUEVO! Escáner láser: Elegimos siempre al zombie que esté físicamente más cerca
	var mas_cercano = null
	var distancia_minima = INF

	for enemigo in enemigos_en_rango:
		# distance_squared_to es matemáticamente más rápido para procesadores de celulares
		var dist = global_position.distance_squared_to(enemigo.global_position)
		if dist < distancia_minima:
			distancia_minima = dist
			mas_cercano = enemigo

	objetivo_actual = mas_cercano

# ==========================================================
# 5. SISTEMA DE DAÑO Y REPARACIÓN
# ==========================================================
func _input_event(camera, event, position, normal, shape_idx):
	var es_clic = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var es_toque = event is InputEventScreenTouch and event.pressed

	if es_clic or es_toque:
		var mundo = get_tree().current_scene
		if mundo.has_method("abrir_menu_inspector"):
			mundo.abrir_menu_inspector(self)

# ==========================================================
# ARMA Y BALAS EN RED
# ==========================================================
# Antes el menú del inspector cambiaba arma_equipada y balas_cargadas solo en
# la pantalla de quien lo usaba. Como la torreta dispara en el servidor, una
# torreta armada por el jugador 2 nunca disparaba. Ahora todo pasa por aquí.

# datos vacío = desinstalar.
@rpc("any_peer", "call_local", "reliable")
func instalar_arma_en_red(datos: Dictionary):
	arma_equipada = null if datos.is_empty() else ArmaData.desde_diccionario(datos)
	if datos.is_empty() and multiplayer.is_server():
		balas_cargadas = 0

@rpc("any_peer", "call_local", "reliable")
func agregar_balas_en_red(cantidad: int):
	if not multiplayer.is_server(): return
	balas_cargadas = max(0, balas_cargadas + cantidad)
