extends JefeIA
# ==========================================================
# MOSCA TITÁN (noche 5) y MOSCA TITÁN DESPERTADA (noche 15)
# ==========================================================
# - Armadura frontal: lo que le pega de frente hace un 20 %. Hay que flanquear.
# - Golpe sísmico: círculo rojo alrededor suyo, luego golpe de área.
# - Embestida: franja roja hacia un jugador y carga a toda velocidad. Si se
#   estrella contra un muro o una barricada queda aturdida y SIN armadura:
#   es la gran ventana para castigarla.
# Despertada: avisos más cortos, puede encadenar dos embestidas, ruge para
# llamar corredores y se regenera si pasa 3 s sin recibir daño.

const ANGULO_FRENTE := 0.35       # dot < -0.35 => la bala venía de frente
const REDUCCION_FRENTE := 0.2
const BONO_ATURDIDA := 1.5
const LIMITE_ARENA := 24.5

var mejorada := false
var _dir_carga := Vector3.ZERO
var _recorrido := 0.0
var _largo_carga := 16.0
var _golpeados: Array = []
var _se_estrello := false
var _cargas_seguidas := 0
var _t_sin_dano := 0.0
var _t_rugido := 18.0

func al_iniciar():
	mejorada = z.tipo_zombie == "mosca_titan_plus"
	usar("embestida", 3.0)
	usar("sismo", 2.0)

func _aviso(base: float) -> float:
	return base * (0.72 if mejorada else 1.0)

func elegir_ataque(dist: float) -> String:
	if listo("sismo") and dist < 5.0: return "sismo"
	if listo("embestida") and dist > 5.0 and dist < 20.0: return "embestida"
	if mejorada and _t_rugido <= 0.0: return "rugido"
	return ""

func al_avisar(nombre: String):
	match nombre:
		"sismo":
			datos_ataque.aviso = _aviso(1.1)
			avisar_circulo(z.global_position, 4.6, datos_ataque.aviso)
			usar("sismo", 4.5 if mejorada else 6.0)
		"embestida":
			mirar_a(objetivo.global_position)
			_dir_carga = direccion_plana(objetivo.global_position)
			_largo_carga = clampf(distancia_plana(objetivo.global_position) + 5.0, 8.0, 20.0)
			datos_ataque.aviso = _aviso(0.95 if _cargas_seguidas == 0 else 0.6)
			avisar_franja(z.global_position, _dir_carga, 2.8, _largo_carga, datos_ataque.aviso)
			usar("embestida", 6.0 if mejorada else 8.0)
		"rugido":
			datos_ataque.aviso = 1.0
			_t_rugido = 22.0
			avisar_circulo(z.global_position, 2.5, 1.0)
			texto("¡RUGIDO!", Color(1, 0.4, 0.3))

func al_ejecutar(nombre: String):
	match nombre:
		"sismo":
			golpe_area(z.global_position, 4.6, 1.6)
		"embestida":
			_recorrido = 0.0
			_golpeados.clear()
			_se_estrello = false
		"rugido":
			if jefes:
				var puntos := jefes.puntos_de_aparicion()
				for i in 4 + 2 * (jugadores - 1):
					jefes.invocar("corredor", puntos[i % puntos.size()])

func procesar_accion(delta: float) -> bool:
	if ataque != "embestida": return true
	var vel := 19.0 if mejorada else 16.0
	z.velocity.x = _dir_carga.x * vel
	z.velocity.z = _dir_carga.z * vel
	_recorrido += vel * delta
	# Atropella a los jugadores que cruza (una vez cada uno).
	if jefes:
		for j in jefes.jugadores_vivos():
			if j in _golpeados: continue
			if distancia_plana(j.global_position) <= 1.9:
				_golpeados.append(j)
				j.recibir_dano_en_red.rpc(dano(1.5))
	# ¿Chocó contra algo? Las barricadas reciben el golpe completo.
	for i in z.get_slide_collision_count():
		var c := z.get_slide_collision(i).get_collider()
		if c and c.is_in_group("barricadas"):
			if c.has_method("recibir_dano"): c.recibir_dano(int(z.dano_estructuras * 2.0))
			_se_estrello = true
		elif c and not c.is_in_group("jugador") and not c.is_in_group("enemigos") and absf(z.get_slide_collision(i).get_normal().y) < 0.5:
			_se_estrello = true
	# El borde de la arena cuenta como muro.
	if absf(z.global_position.x) > LIMITE_ARENA or absf(z.global_position.z) > LIMITE_ARENA:
		z.global_position.x = clampf(z.global_position.x, -LIMITE_ARENA, LIMITE_ARENA)
		z.global_position.z = clampf(z.global_position.z, -LIMITE_ARENA, LIMITE_ARENA)
		_se_estrello = true
	if _se_estrello:
		z.velocity = Vector3.ZERO
		texto("¡ATURDIDA!", Color(1, 0.9, 0.2))
		return true
	if _recorrido >= _largo_carga:
		z.velocity = Vector3.ZERO
		# La Despertada encadena una segunda embestida la mitad de las veces.
		if mejorada and _cargas_seguidas == 0 and randf() < 0.5 and _objetivo_valido():
			_cargas_seguidas = 1
			cooldowns["embestida"] = 0.0
		else:
			_cargas_seguidas = 0
		return true
	return false

func duracion_recuperacion(nombre: String) -> float:
	match nombre:
		"sismo": return 0.9 if mejorada else 1.2
		"embestida":
			if _se_estrello:
				_se_estrello = false
				estado = "aturdido"
				return 3.0
			if _cargas_seguidas == 1: return 0.15
			return 1.2 if mejorada else 1.6
	return 0.8

func procesar_extra(delta: float):
	if mejorada:
		_t_rugido -= delta
		_t_sin_dano += delta
		if _t_sin_dano >= 3.0 and z.salud_actual < z.salud_maxima:
			z.salud_actual = mini(z.salud_maxima, z.salud_actual + int(ceil(z.salud_maxima * 0.015 * delta)))
			if jefes: jefes.marcar_barra()

func texto_estado() -> String:
	if estado == "aturdido": return "¡Aturdida! Sin armadura"
	if mejorada and _t_sin_dano >= 3.0: return "Regenerando…"
	return ""

func modificar_dano(cantidad: int, direccion: Vector3) -> int:
	_t_sin_dano = 0.0
	if estado == "aturdido":
		return int(cantidad * BONO_ATURDIDA)
	if direccion != Vector3.ZERO:
		var d := Vector3(direccion.x, 0, direccion.z).normalized()
		if d.dot(adelante()) < -ANGULO_FRENTE:
			texto("ARMADURA", Color(0.7, 0.75, 0.8), "armadura", 0.8)
			return maxi(1, int(cantidad * REDUCCION_FRENTE))
	return cantidad

func anim_estado(est: String, atq: String) -> Array:
	if est == "aviso" and atq == "embestida": return ["rugido", float(datos_ataque.get("aviso", 0.9)), 2.6]
	if est == "accion" and atq == "embestida": return ["correr", 1.4, 2.2]
	if est == "aviso" and atq == "rugido": return ["rugido", 1.6, 2.4]
	return super.anim_estado(est, atq)
