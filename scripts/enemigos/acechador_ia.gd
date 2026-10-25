extends JefeIA
# ==========================================================
# EL ENJAMBRE (noche 10): los ACECHADORES (3)
# ==========================================================
# Rodean a su presa a media distancia, cada uno por un lado, y saltan por
# turnos con una franja corta de aviso. No pelean cuerpo a cuerpo. Cuando el
# Guardián muere se enfurecen: más rápidos, saltan más seguido.
# Divide el fuego del equipo: si todos le pegan al Guardián, los Acechadores
# te despedazan; si persigues a los Acechadores, el Guardián te alcanza.

const RADIO_ORBITA := 6.5

var _angulo := 0.0
var _sentido := 1.0
var _dir := Vector3.ZERO
var _recorrido := 0.0
var _largo := 8.0
var _golpeados: Array = []
var _furioso := false

func al_iniciar():
	_angulo = randf() * TAU
	_sentido = 1.0 if randf() < 0.5 else -1.0
	usar("salto", randf_range(3.0, 6.0))

func procesar_extra(_delta: float):
	if not _furioso and get_tree().get_nodes_in_group("jefes").filter(func(j): return j.tipo_zombie == "guardian" and not j.esta_muerto).is_empty():
		_furioso = true
		multiplicador_velocidad = 1.35
		multiplicador_dano = 1.25
		texto("¡FURIA!", Color(1, 0.3, 0.2))

func elegir_ataque(dist: float) -> String:
	if listo("salto") and dist < 11.0 and dist > 2.5: return "salto"
	return ""

func perseguir(delta: float, _destino = null):
	# Orbitar alrededor de la presa en vez de ir directo.
	_angulo += _sentido * delta * (0.9 if not _furioso else 1.3)
	var punto: Vector3 = objetivo.global_position + Vector3(cos(_angulo), 0, sin(_angulo)) * RADIO_ORBITA
	super.perseguir(delta, punto)
	mirar_a(objetivo.global_position)

func al_avisar(_nombre: String):
	mirar_a(objetivo.global_position)
	_dir = direccion_plana(objetivo.global_position)
	_largo = clampf(distancia_plana(objetivo.global_position) + 2.0, 4.0, 10.0)
	datos_ataque.aviso = 0.65 if not _furioso else 0.5
	avisar_franja(z.global_position, _dir, 1.7, _largo, datos_ataque.aviso)
	usar("salto", randf_range(4.0, 6.5) * (0.65 if _furioso else 1.0))

func al_ejecutar(_nombre: String):
	_recorrido = 0.0
	_golpeados.clear()

func procesar_accion(delta: float) -> bool:
	var vel := 18.0
	z.velocity.x = _dir.x * vel
	z.velocity.z = _dir.z * vel
	_recorrido += vel * delta
	if jefes:
		for j in jefes.jugadores_vivos():
			if j in _golpeados: continue
			if distancia_plana(j.global_position) <= 1.4:
				_golpeados.append(j)
				j.recibir_dano_en_red.rpc(dano(1.3))
	if _recorrido >= _largo or absf(z.global_position.x) > 24.5 or absf(z.global_position.z) > 24.5:
		z.velocity = Vector3.ZERO
		return true
	return false

func duracion_recuperacion(_nombre: String) -> float:
	return 0.9 if not _furioso else 0.6
