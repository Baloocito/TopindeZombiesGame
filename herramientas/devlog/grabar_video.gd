extends Node
# Graba gameplay con un "jugador demo" (se mueve en círculo y dispara solo).
# Uso: godot --write-movie out.avi --fixed-fps 30 res://tools_tmp/video.tscn -- noche=5 duracion=9 escena=jefe|horda
var args := {}
var m
var j
var t := 0.0
var duracion := 9.0
var iniciado := false
func _ready():
	for a in OS.get_cmdline_user_args():
		var p = a.split("=", true, 1)
		if p.size() == 2: args[p[0]] = p[1]
	duracion = float(args.get("duracion", "9"))
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	EstadoPartida.ids_iniciales = [1]
	m = load("res://scenes/mundo.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)

func _physics_process(delta):
	t += delta
	if not is_instance_valid(m) or not m.is_inside_tree(): return
	if not j: j = m.obtener_jugador_local()
	if not j: return
	if not iniciado and t > 0.6:
		iniciado = true
		j.stat_salud_maxima = int(args.get("vida", "350"))
		j.salud_actual = j.stat_salud_maxima
		j.nivel = int(args.get("nivel", "9"))
		j.actualizar_ui_vida(); j.actualizar_ui_xp()
		var arma_id: String = args.get("arma", "smg")
		var a = Balance.crear_arma(arma_id)
		a.mejoras = int(args.get("mejoras", "0"))
		j.armas_inventario.append(a)
		j.equipar_en_slot(a, 0)
		j.cambiar_arma(0)
		m.oleada_actual = int(args.get("noche", "5"))
		for k in range(int(args.get("vallas", "0"))):
			var ang = TAU * k / 8.0
			var p = Vector3(cos(ang) * 6, 0, sin(ang) * 6)
			m.dinero_global = 99999
			m.solicitar_construccion("madera", m._llave_celda(p), p, 1.0)
		m.dinero_global = int(args.get("oro", "1240"))
		m.actualizar_dinero_para_todos(m.dinero_global)
		if is_instance_valid(m._caja_avisos):
			for av in m._caja_avisos.get_children(): av.queue_free()
		m.iniciar_oleada_en_red()
		for n in m.get_node("InterfazUI").get_children():
			if n is MedidorRendimiento: n.visible = false
		if args.get("escena", "") == "horda":
			var gen0 = m.get_node("GeneradorZombies")
			for i in int(args.get("previos", "14")):
				var ang2 = randf() * TAU
				gen0.crear_enemigo(["basico", "corredor", "tanque", "explosivo", "basico"][i % 5], Vector3(cos(ang2), 0, sin(ang2)) * randf_range(12, 20))
		if args.get("escena", "") == "jefe":
			var gen = m.get_node("GeneradorZombies")
			var tipo = {5: "mosca_titan", 10: "guardian", 15: "mosca_titan_plus", 20: "hospedero"}.get(m.oleada_actual, "mosca_titan")
			gen.pulsos.clear(); gen.cola_de_aparicion.clear()
			var b = gen.crear_enemigo(tipo, Vector3(0, 0, -9))
			m.anunciar_jefe(tipo)
			if tipo == "guardian":
				for i in 3: gen.crear_enemigo("acechador", Vector3(-6 + i * 6, 0, -12))
			if m.oleada_actual == 20 and args.get("fase", "1") == "3":
				b.recibir_dano(int(b.salud_maxima * 0.7))
			# un poco de escolta
			for i in int(args.get("escolta", "4")):
				gen.crear_enemigo(["basico", "corredor"][i % 2], gen.punto_aleatorio())
	if iniciado:
		# Bot: da vueltas, apunta al enemigo más cercano y dispara.
		var radio := float(args.get("radio", "5"))
		var ang := t * float(args.get("giro", "0.45"))
		j.global_position = Vector3(cos(ang) * radio, j.global_position.y, sin(ang) * radio)
		j.municion_reserva[j.arma_actual.tipo_municion] = 240
		# Inmortal para la grabación, pero con la vida real en el HUD.
		if j.esta_caido: j.revivir(1.0)
		if j.salud_actual < j.stat_salud_maxima * 0.6:
			j.salud_actual = j.stat_salud_maxima
			j.actualizar_ui_vida()
		var cerca = null
		var dmin := INF
		for e in get_tree().get_nodes_in_group("enemigos"):
			var d = e.global_position.distance_to(j.global_position)
			if d < dmin and not e.esta_muerto:
				dmin = d; cerca = e
		if cerca and dmin < 16.0:
			var v = cerca.global_position - j.global_position
			j.rotation.y = atan2(v.x, v.z)
			j.can_fire_fase = true
			if j.balas_en_cargador <= 0 and not j.esta_recargando: j.recargar()
			j.intentar_disparar()
	if t > duracion + 0.6:
		get_tree().quit()
