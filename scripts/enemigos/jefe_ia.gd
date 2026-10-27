extends Node
class_name JefeIA
# ==========================================================
# CEREBRO BASE DE LOS JEFES (solo servidor)
# ==========================================================
# Máquina de estados sin awaits (un jefe puede morir a mitad de un ataque):
#   perseguir -> aviso -> accion -> recuperacion -> perseguir
# El aviso SIEMPRE se ve en el suelo antes del golpe: los jefes castigan
# fuerte, pero nunca sin avisar. La recuperación es la ventana para pegarles.

var z: CharacterBody3D        # el zombie dueño de este cerebro
var jefes: JefesMundo
var noche: int = 1
var jugadores: int = 1

var estado: String = "perseguir"
var t_estado: float = 0.0
var ataque: String = ""
var datos_ataque: Dictionary = {}
var cooldowns: Dictionary = {}      # ataque -> segundos que faltan
var objetivo: Node3D = null
var _t_objetivo: float = 0.0
var _t_nav: float = 0.0
var multiplicador_velocidad: float = 1.0
var multiplicador_dano: float = 1.0

func iniciar(dueno: CharacterBody3D, n: int, p: int):
	z = dueno
	noche = n
	jugadores = p
	jefes = z.get_parent().get_node_or_null("Jefes")
	if z.tipo_zombie != "nodo":
		z.add_to_group("jefes")
		if jefes: jefes.marcar_barra()
	al_iniciar()

# --- Para sobrescribir ---
func al_iniciar(): pass
func elegir_ataque(_dist: float) -> String: return ""
func al_avisar(_nombre: String): pass        # dibuja el aviso y fija datos_ataque
func al_ejecutar(_nombre: String): pass      # el golpe
func procesar_accion(_delta: float) -> bool: return true  # true = terminó la acción
func duracion_recuperacion(_nombre: String) -> float: return 1.0
func procesar_extra(_delta: float): pass     # temporizadores propios (invocar, fases…)
func texto_estado() -> String: return ""
func modificar_dano(cantidad: int, _direccion: Vector3) -> int: return cantidad
func al_recibir_dano(_cantidad: int):
	if jefes: jefes.marcar_barra()
func al_morir():
	if jefes: jefes.jefe_murio()

# ----------------------------------------------------------
# Animación que acompaña cada estado: [nombre, duración, velocidad] o [].
func anim_estado(est: String, _ataque: String) -> Array:
	match est:
		"aviso": return ["golpe", float(datos_ataque.get("aviso", 1.0)) + 0.6, 1.6]
		"aturdido": return ["reposo", t_estado, 1.0]
		"quieto": return ["rugido", t_estado, 2.0]
	return []

var _estado_animado := ""
func _animar_si_cambio():
	if estado == _estado_animado: return
	_estado_animado = estado
	var a := anim_estado(estado, ataque)
	if not a.is_empty() and z.has_method("animar_en_red"):
		z.animar_en_red.rpc(a[0], a[1], a[2])

func procesar(delta: float):
	_animar_si_cambio()
	for k in cooldowns.keys():
		cooldowns[k] = maxf(0.0, cooldowns[k] - delta)
	_t_objetivo -= delta
	if _t_objetivo <= 0.0 or not _objetivo_valido():
		_t_objetivo = 0.5
		objetivo = z.buscar_presa_mas_cercana()
	procesar_extra(delta)
	if not is_instance_valid(z) or z.esta_muerto: return
	t_estado -= delta
	match estado:
		"perseguir":
			if not _objetivo_valido():
				_frenar()
				return
			var dist := distancia_plana(objetivo.global_position)
			var elegido := elegir_ataque(dist)
			if elegido != "":
				_frenar()
				ataque = elegido
				datos_ataque = {}
				estado = "aviso"
				al_avisar(ataque)
				t_estado = float(datos_ataque.get("aviso", 1.0))
				return
			perseguir(delta)
		"aviso":
			_frenar()
			if t_estado <= 0.0:
				al_ejecutar(ataque)
				estado = "accion"
		"accion":
			if procesar_accion(delta):
				estado = "recuperacion"
				t_estado = duracion_recuperacion(ataque)
				_frenar()
		"recuperacion":
			_frenar()
			if t_estado <= 0.0:
				estado = "perseguir"
		"aturdido":
			_frenar()
			if t_estado <= 0.0:
				estado = "perseguir"
		"quieto":
			_frenar()

func _objetivo_valido() -> bool:
	return is_instance_valid(objetivo) and objetivo.salud_actual > 0 and not objetivo.esta_caido

func distancia_plana(p: Vector3) -> float:
	return Vector2(p.x - z.global_position.x, p.z - z.global_position.z).length()

func direccion_plana(p: Vector3) -> Vector3:
	var d := Vector3(p.x - z.global_position.x, 0, p.z - z.global_position.z)
	return d.normalized() if d.length() > 0.01 else -z.global_basis.z

func mirar_a(p: Vector3):
	var d := direccion_plana(p)
	z.rotation.y = atan2(-d.x, -d.z)

func adelante() -> Vector3:
	var f := -z.global_basis.z
	f.y = 0
	return f.normalized()

func _frenar():
	z.velocity.x = move_toward(z.velocity.x, 0, z.velocidad)
	z.velocity.z = move_toward(z.velocity.z, 0, z.velocidad)

# Camina hacia el objetivo con el NavigationAgent; golpea cuerpo a cuerpo si
# está pegado y rompe las barricadas con las que choca.
func perseguir(delta: float, destino = null):
	var meta: Vector3 = destino if destino != null else objetivo.global_position
	_t_nav -= delta
	if _t_nav <= 0.0:
		_t_nav = 0.25
		z.agente_nav.target_position = meta
	var paso: Vector3 = z.agente_nav.get_next_path_position()
	var dir := direccion_plana(paso)
	var vel: float = z.velocidad * multiplicador_velocidad
	z.velocity.x = dir.x * vel
	z.velocity.z = dir.z * vel
	if dir.length() > 0.1: z.rotation.y = lerp_angle(z.rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)
	if destino == null and distancia_plana(meta) <= z.rango_ataque and z.puede_atacar:
		z.atacar(objetivo)
	z.revisar_colisiones()

func dano(mult: float) -> int:
	return int(z.dano_ataque_actual * mult * multiplicador_dano)

func avisar_circulo(pos: Vector3, radio: float, t: float):
	if jefes: jefes.telegrafo_en_red.rpc(0, pos, 0.0, Vector2(radio, 0), t)

func avisar_franja(pos: Vector3, dir: Vector3, ancho: float, largo: float, t: float):
	if jefes: jefes.telegrafo_en_red.rpc(1, pos, atan2(-dir.x, -dir.z), Vector2(ancho, largo), t)

func texto(t: String, color: Color, clave: String = "", cada: float = 0.6):
	if not jefes: return
	var pos: Vector3 = z.global_position + Vector3(0, z.scale.y * 1.2, 0)
	if clave == "": jefes.texto_en_red.rpc(pos, t, color)
	else: jefes.texto_limitado(clave + str(z.get_instance_id()), pos, t, color, cada)

func listo(nombre: String) -> bool:
	return float(cooldowns.get(nombre, 0.0)) <= 0.0

func usar(nombre: String, segundos: float):
	cooldowns[nombre] = segundos

# Golpe en el suelo alrededor de un punto (jugadores y estructuras).
func golpe_area(pos: Vector3, radio: float, mult: float):
	if not jefes: return
	jefes.danar_jugadores_en_radio(pos, radio, dano(mult))
	jefes.danar_estructuras_en_radio(pos, radio, int(z.dano_estructuras * mult))
