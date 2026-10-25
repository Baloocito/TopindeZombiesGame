extends Node
class_name LootMundo
# ==========================================================
# LOOT (solo el servidor decide qué cae)
# ==========================================================
# Separado de mundo.gd. Usa la tabla de data/zombies.json y los umbrales de
# data/progresion.json (Manual v3 §9). Cada objeto se configura ANTES de
# agregarlo al mundo, para que el spawn lleve sus datos a todos los clientes.

var m: Node  # el nodo Mundo
var modificador_suerte: float = 0.0  # pity: sube con cada baja que no soltó nada

func spawn_loot(pos_muerte: Vector3, tipo_zombie: String):
	if not multiplayer.is_server(): return
	var datos := Balance.zombie(tipo_zombie)
	var noche: int = m.oleada_actual
	var jugadores := maxi(1, get_tree().get_nodes_in_group("jugador").size())

	m.sumar_dinero(int(datos["oro_bounty"]))
	m.dar_experiencia_equipo.rpc(Balance.xp_por_baja(tipo_zombie, jugadores))

	var es_elite := tipo_zombie == "tanque" or Balance.es_jefe(tipo_zombie)
	var umbral_municion := float(Balance.loot("umbral_municion"))
	var umbral_botiquin := float(Balance.loot("umbral_botiquin"))
	var umbral_plano := float(Balance.loot("umbral_plano"))

	# El loot se adapta al jugador más cercano: si está herido salen más
	# botiquines, si le queda poca munición, más cajas.
	var cercano = _jugador_mas_cercano(pos_muerte)
	if cercano:
		if cercano.salud_actual <= cercano.stat_salud_maxima * 0.3:
			umbral_botiquin = 60.0
			umbral_municion = 96.0
		if cercano.arma_actual:
			var reserva = cercano.municion_reserva.get(cercano.arma_actual.tipo_municion, 0)
			if reserva <= cercano.arma_actual.tamano_cargador:
				umbral_municion = 40.0

	var dado := randf_range(1.0, 100.0) + modificador_suerte
	var solto_algo := false

	if dado >= umbral_municion and dado < umbral_botiquin and not es_elite:
		solto_algo = _soltar_municion(pos_muerte, cercano)
	elif dado >= umbral_botiquin and dado < umbral_plano and not es_elite:
		solto_algo = _soltar(m.botiquin_escena, pos_muerte, 0.5)
	elif dado >= umbral_plano or es_elite:
		solto_algo = _soltar_plano(pos_muerte, noche, es_elite)

	modificador_suerte = 0.0 if solto_algo else modificador_suerte + float(Balance.loot("pity_por_fallo"))

	if randf() <= float(datos["prob_oro"]):
		var oro := Balance.oro_por_baja(tipo_zombie, noche)
		if oro > 0 and m.moneda_escena:
			var moneda = m.moneda_escena.instantiate()
			moneda.valor_oro = oro
			_agregar(moneda, pos_muerte + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)))

func generar_chatarra(posicion: Vector3):
	if not multiplayer.is_server() or not m.moneda_escena: return
	var chatarra = m.moneda_escena.instantiate()
	chatarra.valor_oro = int(Balance.loot("valor_chatarra_estructura"))
	_agregar(chatarra, posicion)

func _soltar_municion(pos: Vector3, cercano) -> bool:
	if not m.caja_municion_escena: return false
	var caja = m.caja_municion_escena.instantiate()
	var tipo := "Ligera"
	var cargador := 12
	if cercano and cercano.arma_actual:
		tipo = cercano.arma_actual.tipo_municion
		cargador = cercano.arma_actual.tamano_cargador
	var mult := int(Balance.loot("multiplicador_municion_ligera")) if tipo == "Ligera" else int(Balance.loot("multiplicador_municion_otra"))
	caja.configurar(tipo, cargador * mult)
	_agregar(caja, pos + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5)))
	return true

func _soltar_plano(pos: Vector3, noche: int, es_elite: bool) -> bool:
	if not m.plano_arma_escena: return false
	var plano = m.plano_arma_escena.instantiate()
	if not plano.generar_plano(Balance.tier_plano_maximo(noche), es_elite):
		plano.free()
		return false
	_agregar(plano, pos + Vector3(0, 0.5, 0))
	return true

func _soltar(escena: PackedScene, pos: Vector3, dispersion: float) -> bool:
	if not escena: return false
	_agregar(escena.instantiate(), pos + Vector3(randf_range(-dispersion, dispersion), 0, randf_range(-dispersion, dispersion)))
	return true

# Hijo directo de Mundo: ahí lo vigila SpawnerEntidades (spawn_path "..").
func _agregar(nodo: Node3D, pos: Vector3):
	nodo.position = pos
	m.add_child(nodo, true)

func _jugador_mas_cercano(pos: Vector3):
	var mejor = null
	var dist := INF
	for jug in get_tree().get_nodes_in_group("jugador"):
		if not is_instance_valid(jug) or jug.esta_caido: continue
		var d: float = jug.global_position.distance_to(pos)
		if d < dist:
			dist = d
			mejor = jug
	return mejor
