extends AnimationPlayer
class_name Animador
# ==========================================================
# ANIMACIONES DE MIXAMO PARA LOS PERSONAJES PSX
# ==========================================================
# Todos los personajes usan el esqueleto de Mixamo, así que las mismas
# animaciones (assets/animaciones/mixamo) sirven para todos. Al cargarlas:
#   - se quitan las pistas de huesos que el modelo no tiene (dedos, etc.);
#   - la cadera deja de avanzar (las animaciones de Mixamo que no son
#     "in place" mueven el cuerpo; acá el movimiento lo pone el juego);
#   - la altura de la cadera se ajusta a la del modelo (si no, flota o se hunde).
# Las librerías resultantes se guardan en caché por tipo de esqueleto.

const RUTA := "res://assets/animaciones/mixamo/"
const CONJUNTOS := {
	"zombie": {"reposo": "zombie_reposo", "caminar": "zombie_caminar", "correr": "zombie_correr",
		"golpe": "zombie_golpe", "mordida": "zombie_mordida", "grito": "zombie_grito",
		"impacto": "zombie_impacto", "arrastre": "zombie_arrastre", "muerte": "zombie_muerte"},
	"prota": {"pistola_reposo": "pistola_reposo", "pistola_correr": "pistola_correr",
		"pistola_atras": "pistola_atras", "pistola_lado": "pistola_lado", "pistola_recarga": "pistola_recarga",
		"rifle_reposo": "rifle_reposo", "rifle_correr": "rifle_correr", "rifle_atras": "rifle_atras",
		"rifle_izq": "rifle_izq", "rifle_der": "rifle_der", "rifle_recarga": "rifle_recarga",
		"impacto": "prota_impacto", "muerte": "prota_muerte"},
	"jefe": {"reposo": "jefe_reposo", "caminar": "jefe_caminar", "correr": "jefe_correr",
		"golpe": "jefe_golpe", "salto": "jefe_salto", "rugido": "jefe_rugido", "muerte": "jefe_muerte"},
}
const EN_BUCLE := ["reposo", "caminar", "correr", "arrastre", "pistola_reposo", "pistola_correr", "pistola_atras",
	"pistola_lado", "rifle_reposo", "rifle_correr", "rifle_atras", "rifle_izq", "rifle_der"]
const CADERA := "mixamorig_Hips"

static var _cache: Dictionary = {}      # clave -> AnimationLibrary
static var _fuentes: Dictionary = {}    # archivo -> Animation original

var actual: String = ""
var _accion_hasta: float = 0.0          # mientras dure un golpe/salto/rugido no se pisa

# Agrega el animador al modelo `raiz` (el nodo que contiene "Skeleton3D").
static func para(raiz: Node3D, conjunto: String) -> Animador:
	# El FBX trae su propio AnimationPlayer con la pose en T: se quita.
	for viejo in raiz.find_children("*", "AnimationPlayer", true, false):
		viejo.get_parent().remove_child(viejo)
		viejo.free()
	var esq := raiz.find_child("Skeleton3D", true, false) as Skeleton3D
	var a := Animador.new()
	a.name = "Animador"
	raiz.add_child(a)
	a.root_node = NodePath("..")
	if esq:
		a.add_animation_library("", _libreria(conjunto, esq))
	a.playback_default_blend_time = 0.18
	return a

static func _libreria(conjunto: String, esq: Skeleton3D) -> AnimationLibrary:
	var cadera := esq.find_bone(CADERA)
	var reposo: Vector3 = esq.get_bone_rest(cadera).origin if cadera >= 0 else Vector3.UP
	var eje := _eje_vertical(reposo)
	var clave := "%s|%d|%d|%s" % [conjunto, esq.get_bone_count(), int(round(absf(reposo.dot(eje)) * 20.0)), eje]
	if _cache.has(clave): return _cache[clave]
	var huesos := {}
	for i in esq.get_bone_count(): huesos[esq.get_bone_name(i)] = true
	var lib := AnimationLibrary.new()
	for nombre in CONJUNTOS[conjunto].keys():
		var fuente := _fuente(CONJUNTOS[conjunto][nombre])
		if not fuente: continue
		var anim := fuente.duplicate(true) as Animation
		if fuente.has_meta("cadera_reposo"): anim.set_meta("cadera_reposo", fuente.get_meta("cadera_reposo"))
		var t := anim.get_track_count() - 1
		while t >= 0:
			var ruta := anim.track_get_path(t)
			var hueso := String(ruta.get_concatenated_subnames())
			if hueso != "" and not huesos.has(hueso):
				anim.remove_track(t)
			elif hueso == CADERA and anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
				_fijar_cadera(anim, t, reposo, eje)
			t -= 1
		anim.loop_mode = Animation.LOOP_LINEAR if nombre in EN_BUCLE else Animation.LOOP_NONE
		lib.add_animation(nombre, anim)
	_cache[clave] = lib
	return lib

static func _fuente(archivo: String) -> Animation:
	if _fuentes.has(archivo): return _fuentes[archivo]
	var escena = load(RUTA + archivo + ".fbx")
	var anim: Animation = null
	if escena:
		var n: Node = escena.instantiate()
		var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap and not ap.get_animation_list().is_empty():
			anim = ap.get_animation(ap.get_animation_list()[0])
			# Altura de la cadera del esqueleto con que se exportó: es la
			# referencia para escalar (no el primer cuadro, que en el
			# arrastre o la muerte ya está agachado).
			var esq := n.find_child("Skeleton3D", true, false) as Skeleton3D
			if esq and esq.find_bone(CADERA) >= 0:
				anim.set_meta("cadera_reposo", esq.get_bone_rest(esq.find_bone(CADERA)).origin.y)
		n.free()
	_fuentes[archivo] = anim
	return anim

# Eje "arriba" del espacio donde vive la cadera: casi siempre +Y, pero los
# modelos que llegan de Tripo -> Mixamo traen el esqueleto con Z hacia arriba.
static func _eje_vertical(reposo: Vector3) -> Vector3:
	var a := reposo.abs()
	if a.y >= a.x and a.y >= a.z: return Vector3.UP * signf(reposo.y if reposo.y != 0.0 else 1.0)
	if a.z >= a.x: return Vector3.BACK * signf(reposo.z)
	return Vector3.RIGHT * signf(reposo.x)

# La cadera queda en el lugar (sin avanzar) y a la altura del modelo: la
# altura de la animación (eje Y del esqueleto de Mixamo) se escala a la del
# modelo y se pone sobre su eje vertical.
static func _fijar_cadera(anim: Animation, t: int, reposo: Vector3, eje: Vector3):
	var n := anim.track_get_key_count(t)
	if n == 0: return
	var inicio: Vector3 = anim.track_get_key_value(t, 0)
	var referencia := float(anim.get_meta("cadera_reposo", inicio.y))
	var alto := reposo.dot(eje)
	var plano := reposo - eje * alto
	var proporcion := alto / maxf(0.01, referencia)
	for k in n:
		var v: Vector3 = anim.track_get_key_value(t, k)
		anim.track_set_key_value(t, k, plano + eje * (v.y * proporcion))

# Cambia de animación solo si hace falta (no reinicia la que ya está sonando).
func poner(nombre: String, velocidad: float = 1.0):
	if Time.get_ticks_msec() / 1000.0 < _accion_hasta: return
	if not has_animation(nombre): return
	speed_scale = velocidad
	if actual == nombre: return
	actual = nombre
	play(nombre)

# Una acción (golpe, salto, rugido): suena entera, o `duracion` segundos.
func accion(nombre: String, duracion: float = -1.0, velocidad: float = 1.0):
	if not has_animation(nombre): return
	actual = nombre
	speed_scale = velocidad
	play(nombre, 0.1)
	var largo := get_animation(nombre).length / maxf(0.01, absf(velocidad))
	_accion_hasta = Time.get_ticks_msec() / 1000.0 + (duracion if duracion > 0.0 else largo)

func terminar_accion():
	_accion_hasta = 0.0

func revivir():
	_accion_hasta = 0.0
	actual = ""

# Muerte: suena una vez y queda en el último cuadro.
func morir():
	_accion_hasta = INF
	if has_animation("muerte"):
		actual = "muerte"
		speed_scale = 1.0
		play("muerte", 0.1)
