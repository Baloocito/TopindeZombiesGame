extends JefeIA
# ==========================================================
# EL HOSPEDERO (noche 20): jefe final de 3 fases (Manual v3 §7)
# ==========================================================
# Fase 1 (100–66 %): golpe de área, proyectiles a distancia y llamadas de
#   zombies. En coop, cada jugador extra abre un lado de la arena por donde
#   entran corredores.
# Fase 2 (66–33 %): además lanza ATADURAS (círculo bajo un jugador): quien
#   quede adentro no puede moverse. Solo: te liberas a los 3 s. Coop: solo te
#   libera un compañero a menos de 2 m.
# Fase 3 (33–0 %): se enfurece (+50 % velocidad y daño), el suelo se
#   contamina por zonas y se cubre con un ESCUDO. Aparecen nodos de energía
#   (tantos como jugadores, mínimo 2): hay que romperlos casi a la vez para
#   exponerlo. Si no, los rotos se regeneran.

const ESQUINAS_NODOS := [Vector3(15, 0, 15), Vector3(-15, 0, -15), Vector3(15, 0, -15), Vector3(-15, 0, 15)]
const CENTROS_ZONAS := [Vector3(11, 0, 11), Vector3(-11, 0, 11), Vector3(11, 0, -11), Vector3(-11, 0, -11)]
const RADIO_ATADURA := 1.8
const DURACION_EXPUESTO := 12.0

var fase := 1
var _invulnerable_t := 0.0
var _t_llamada := 10.0
var _t_atadura := 6.0
var _t_zona := 3.0
var _ataduras_pendientes: Array = []   # {pos, t}
var _lanzamientos: Array = []          # {pos, t}
var escudo := false
var _nodos: Array = []                 # {pos, nodo}
var _t_ventana := -1.0
var _t_expuesto := 0.0

func al_iniciar():
	usar("sismo", 3.0)
	usar("lanzamiento", 4.0)

func _ventana_nodos() -> float:
	return 5.0 if jugadores <= 1 else 3.0

# ----------------------------------------------------------
# ATAQUES
# ----------------------------------------------------------
func elegir_ataque(dist: float) -> String:
	if listo("sismo") and dist < 5.5: return "sismo"
	if listo("lanzamiento") and dist > 4.0: return "lanzamiento"
	return ""

func al_avisar(nombre: String):
	match nombre:
		"sismo":
			datos_ataque.aviso = 1.2 if fase < 3 else 0.9
			avisar_circulo(z.global_position, 5.5, datos_ataque.aviso)
			usar("sismo", 5.0 if fase < 3 else 3.5)
		"lanzamiento":
			datos_ataque.aviso = 0.35
			# En la fase 3 lanza a todos los jugadores a la vez (y uno extra al azar).
			var blancos: Array = [objetivo]
			if fase >= 3 and jefes: blancos = jefes.jugadores_vivos()
			for j in blancos:
				_lanzar(j.global_position)
			if fase >= 3 and not blancos.is_empty():
				_lanzar(blancos.pick_random().global_position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
			usar("lanzamiento", 6.0 if fase < 3 else 4.5)

func _lanzar(pos: Vector3):
	var t := 1.3
	avisar_circulo(pos, 2.4, t)
	_lanzamientos.append({"pos": pos, "t": t})

func al_ejecutar(nombre: String):
	if nombre == "sismo":
		golpe_area(z.global_position, 5.5, 1.6)

func duracion_recuperacion(nombre: String) -> float:
	if nombre == "sismo": return 1.3 if fase < 3 else 0.8
	return 0.4

# ----------------------------------------------------------
# FASES, LLAMADAS, ATADURAS, ZONAS Y NODOS
# ----------------------------------------------------------
func procesar_extra(delta: float):
	var frac := float(z.salud_actual) / float(z.salud_maxima)
	if fase == 1 and frac <= 0.66: _entrar_fase(2)
	elif fase == 2 and frac <= 0.33: _entrar_fase(3)
	_invulnerable_t = maxf(0.0, _invulnerable_t - delta)

	# Proyectiles a distancia.
	for l in _lanzamientos.duplicate():
		l.t -= delta
		if l.t <= 0.0:
			_lanzamientos.erase(l)
			if jefes:
				jefes.danar_jugadores_en_radio(l.pos, 2.4, dano(1.2))
				jefes.danar_estructuras_en_radio(l.pos, 2.4, int(z.dano_estructuras * 0.6))

	# Llamadas de zombies.
	_t_llamada -= delta
	if _t_llamada <= 0.0:
		_t_llamada = [14.0, 18.0, 16.0][fase - 1]
		_llamar()

	# Ataduras (fase 2 en adelante).
	if fase >= 2:
		_t_atadura -= delta
		if _t_atadura <= 0.0 and jefes:
			_t_atadura = 8.0 if jugadores <= 1 else 7.0
			var vivos := jefes.jugadores_vivos()
			if not vivos.is_empty():
				var blanco = vivos.pick_random()
				avisar_circulo(blanco.global_position, RADIO_ATADURA, 1.1)
				_ataduras_pendientes.append({"pos": blanco.global_position, "t": 1.1})
	for a in _ataduras_pendientes.duplicate():
		a.t -= delta
		if a.t <= 0.0:
			_ataduras_pendientes.erase(a)
			if jefes:
				for j in jefes.jugadores_vivos():
					if Vector2(j.global_position.x - a.pos.x, j.global_position.z - a.pos.z).length() <= RADIO_ATADURA:
						j.atar_en_red.rpc(3.0, jugadores > 1)

	if fase >= 3:
		_procesar_fase3(delta)

func _entrar_fase(nueva: int):
	fase = nueva
	_invulnerable_t = 2.5
	estado = "quieto"
	t_estado = 2.5
	_t_llamada = 1.5
	if jefes:
		jefes.m.mostrar_aviso.rpc("El Hospedero cambia… FASE %d" % fase)
	texto("FASE %d" % fase, Color(0.8, 0.4, 1.0))
	avisar_circulo(z.global_position, 6.5, 2.4)
	if nueva == 3:
		multiplicador_velocidad = 1.5
		multiplicador_dano = 1.5
		escudo = true
		_crear_nodos(true)

func procesar(delta: float):
	_animar_si_cambio()
	# El estado "quieto" de la transición dura t_estado.
	if estado == "quieto":
		t_estado -= delta
		procesar_extra(delta)
		_frenar()
		if t_estado <= 0.0:
			estado = "perseguir"
			if fase >= 2 and jefes:
				golpe_area(z.global_position, 6.5, 1.4)
		return
	super.procesar(delta)

func _llamar():
	if not jefes: return
	var puntos := jefes.puntos_de_aparicion()
	if puntos.is_empty(): return
	for i in 3:
		jefes.invocar("basico", puntos.pick_random())
	# Coop: un lado más peligroso por cada jugador extra.
	for i in jugadores - 1:
		for k in 3:
			jefes.invocar("corredor", puntos[i % puntos.size()])
	if fase >= 3:
		jefes.invocar("explosivo", puntos.pick_random())

func _procesar_fase3(delta: float):
	# Suelo contaminado.
	_t_zona -= delta
	if _t_zona <= 0.0 and jefes:
		_t_zona = 7.0
		var cuantas := 1 if jugadores < 3 else 2
		var centros := CENTROS_ZONAS.duplicate()
		centros.shuffle()
		for i in cuantas:
			jefes.agregar_zona(centros[i], 5.5, 1.5, 6.0, int(Balance.escalar_dano(12.0, noche) * Balance.furia_noche(noche)))
	# Ventana para romper los nodos casi a la vez.
	if _t_ventana >= 0.0:
		_t_ventana -= delta
		if _t_ventana < 0.0:
			if _nodos_vivos() > 0:
				_crear_nodos(false)
				if jefes: jefes.m.mostrar_aviso.rpc("¡Los nodos se regeneraron! Rómpanlos a la vez.")
	# Expuesto: sin escudo un rato; luego vuelve con nodos nuevos.
	if not escudo:
		_t_expuesto -= delta
		if _t_expuesto <= 0.0:
			escudo = true
			_crear_nodos(true)
			texto("ESCUDO", Color(0.4, 0.9, 1.0))
			if jefes: jefes.marcar_barra()

func _nodos_vivos() -> int:
	var n := 0
	for d in _nodos:
		if is_instance_valid(d.nodo) and not d.nodo.esta_muerto: n += 1
	return n

# todos = true: nodos nuevos en todas las esquinas elegidas. false: solo
# vuelven los que estaban rotos.
func _crear_nodos(todos: bool):
	if not jefes: return
	_t_ventana = -1.0
	if todos:
		for d in _nodos:
			if is_instance_valid(d.nodo): d.nodo.queue_free()
		_nodos.clear()
		var esquinas := ESQUINAS_NODOS.duplicate()
		esquinas.shuffle()
		for i in clampi(maxi(2, jugadores), 2, 4):
			_nodos.append({"pos": esquinas[i], "nodo": null})
	for d in _nodos:
		if not is_instance_valid(d.nodo) or d.nodo.esta_muerto:
			var n = jefes.invocar("nodo", d.pos)
			if n:
				n.global_position = d.pos
				n.ia.hospedero = self
			d.nodo = n
	jefes.marcar_barra()

func nodo_destruido(_nodo):
	if not escudo: return
	# El nodo que avisa ya está marcado como muerto (esta_muerto).
	var quedan := _nodos_vivos()
	if quedan <= 0:
		_t_ventana = -1.0
		escudo = false
		_t_expuesto = DURACION_EXPUESTO
		estado = "aturdido"
		t_estado = 3.0
		texto("¡EXPUESTO!", Color(1, 0.9, 0.2))
		if jefes:
			jefes.m.mostrar_aviso.rpc("¡El Hospedero está expuesto! ¡Ahora!")
			jefes.marcar_barra()
	elif _t_ventana < 0.0:
		_t_ventana = _ventana_nodos()
		if jefes: jefes.m.mostrar_aviso.rpc("¡Nodo roto! Quedan %d: %.0f s para romperlos." % [quedan, _ventana_nodos()])

func texto_estado() -> String:
	var base := "Fase %d" % fase
	if fase >= 3:
		if escudo: base += " · Escudo: rompe los nodos (%d)" % _nodos_vivos()
		else: base += " · ¡Expuesto!"
	return base

func modificar_dano(cantidad: int, _direccion: Vector3) -> int:
	if _invulnerable_t > 0.0 or escudo:
		texto("ESCUDO" if escudo else "INMUNE", Color(0.4, 0.9, 1.0), "escudo", 0.8)
		return 0
	if estado == "aturdido":
		return int(cantidad * 1.5)
	return cantidad

func al_morir():
	for d in _nodos:
		if is_instance_valid(d.nodo): d.nodo.queue_free()
	_nodos.clear()
	if jefes: jefes.limpiar_zonas()
	super.al_morir()

func anim_estado(est: String, atq: String) -> Array:
	if est == "aviso" and atq == "lanzamiento": return ["golpe", 1.0, 2.6]
	return super.anim_estado(est, atq)
