extends Node
# ==========================================================
# BALANCE: única fuente de los números del juego (Manual v3)
# ==========================================================
# Lee data/*.json al arrancar. Ningún script debería tener precios, vidas,
# daños ni fórmulas de escalado escritos a mano: se piden aquí. Para ajustar
# el juego se edita el JSON, no el código.

const RUTA_DATOS := "res://data/"

var armas: Dictionary = {}
var zombies: Dictionary = {}
var estructuras: Dictionary = {}
var progresion: Dictionary = {}
var campana: Dictionary = {}

func _init():
	armas = _cargar("armas.json")
	zombies = _cargar("zombies.json")
	estructuras = _cargar("estructuras.json")
	progresion = _cargar("progresion.json")
	campana = _cargar("campana.json")

func _cargar(archivo: String) -> Dictionary:
	var ruta := RUTA_DATOS + archivo
	var texto := FileAccess.get_file_as_string(ruta)
	if texto == "":
		push_error("Balance: no se pudo leer %s" % ruta)
		return {}
	var datos = JSON.parse_string(texto)
	if typeof(datos) != TYPE_DICTIONARY:
		push_error("Balance: %s no es un JSON válido" % ruta)
		return {}
	datos.erase("_nota")
	return datos

func _esc(clave: String) -> float:
	return float(progresion["escalado"][clave])

# ----------------------------------------------------------
# ARMAS
# ----------------------------------------------------------
func ids_armas() -> Array:
	return armas.keys()

func arma(id: String) -> Dictionary:
	return armas.get(id, {})

# Crea un ArmaData nuevo (nunca compartido) a partir del JSON.
func crear_arma(id: String) -> ArmaData:
	var d := arma(id)
	if d.is_empty():
		push_error("Balance: arma desconocida '%s'" % id)
		return null
	var a := ArmaData.new()
	a.id = id
	a.nombre = d["nombre"]
	a.tipo_municion = d["municion"]
	a.dano = int(d["dano"])
	a.cadencia = float(d["cadencia"])
	a.tamano_cargador = int(d["cargador"])
	a.tiempo_recarga = float(d["recarga"])
	a.balas_por_disparo = int(d["balas_por_disparo"])
	a.dispersion = float(d["dispersion"])
	a.dano_area = int(d["dano_area"])
	a.penetra_enemigos = bool(d["penetra"])
	return a

func tier_arma(id: String) -> int:
	return int(arma(id).get("tier", 1))

# ----------------------------------------------------------
# ZOMBIES Y DIFICULTAD (Manual v3 §8)
# ----------------------------------------------------------
func zombie(tipo: String) -> Dictionary:
	return zombies.get(tipo, zombies.get("basico", {}))

func escalar_vida(base: float, noche: int) -> int:
	var campana := int(_esc("noches_campana"))
	if noche <= campana:
		return int(base * (1.0 + _esc("vida_por_noche") * (noche - 1)))
	return int(base * (1.0 + _esc("vida_por_noche") * (campana - 1) + _esc("vida_por_noche_eternas") * (noche - campana)))

func escalar_dano(base: float, noche: int) -> int:
	return int(base * (1.0 + _esc("dano_por_noche") * (noche - 1)))

func escalar_velocidad(base: float, noche: int) -> float:
	return base * (1.0 + minf(_esc("velocidad_tope"), _esc("velocidad_por_noche") * (noche - 1)))

func presupuesto_noche(noche: int, jugadores: int) -> int:
	return int(float(noche_campana(noche)["presupuesto"]) * (1.0 + _esc("presupuesto_por_jugador") * (maxi(1, jugadores) - 1)))

func max_simultaneos(noche: int, jugadores: int) -> int:
	var v := float(noche_campana(noche)["simultaneos"]) * (1.0 + _esc("simultaneos_por_jugador") * (maxi(1, jugadores) - 1))
	return int(minf(_esc("simultaneos_tope"), v))

# ----------------------------------------------------------
# CAMPAÑA (data/campana.json)
# ----------------------------------------------------------
func noches_campana() -> int:
	return int(_esc("noches_campana"))

func es_noche_eterna(noche: int) -> bool:
	return noche > noches_campana()

# Datos de una noche: las 20 de la campaña vienen escritas a mano; desde la
# 21 (Noches Eternas) se generan a partir de la 20 y crecen sin tope.
func noche_campana(noche: int) -> Dictionary:
	var tabla: Array = campana.get("noches", [])
	if tabla.is_empty(): return {"presupuesto": 80, "simultaneos": 16, "pulsos": 1, "intervalo": 1.5, "mezcla": {"basico": 1}}
	if noche >= 1 and noche <= tabla.size():
		return tabla[noche - 1]
	var base: Dictionary = (tabla[tabla.size() - 1] as Dictionary).duplicate(true)
	var et: Dictionary = campana.get("eternas", {})
	var extra := noche - tabla.size()
	base["n"] = noche
	base["nombre"] = "Noche Eterna %d" % noche
	base["lema"] = "Nadie llegó tan lejos."
	base["presupuesto"] = float(base["presupuesto"]) * (1.0 + float(et.get("presupuesto_por_noche", 0.15)) * extra)
	base["simultaneos"] = float(base["simultaneos"]) + float(et.get("simultaneos_por_noche", 1)) * extra
	base["furia"] = float(base.get("furia", 1.0)) + float(et.get("furia_por_noche", 0.03)) * extra
	base.erase("jefe")
	base["jefe_en_pulso"] = 0
	if noche % int(_esc("cada_cuantas_noches_jefe")) == 0:
		var jefes: Array = et.get("jefes", ["mosca_titan_plus"])
		base["jefe"] = jefes[(noche / int(_esc("cada_cuantas_noches_jefe"))) % jefes.size()]
	return base

func furia_noche(noche: int) -> float:
	return float(noche_campana(noche).get("furia", 1.0))

func velocidad_noche(noche: int) -> float:
	return float(noche_campana(noche).get("velocidad", 1.0))

func es_jefe(tipo: String) -> bool:
	return bool(zombie(tipo).get("jefe", false))

func nombre_enemigo(tipo: String) -> String:
	return str(zombie(tipo).get("nombre", tipo.capitalize()))

func dps_esperado(noche: int) -> float:
	return _esc("dps_esperado_base") * (1.0 + _esc("dps_esperado_por_noche") * (noche - 1))

func es_noche_de_jefe(noche: int) -> bool:
	return noche_campana(noche).has("jefe")

func vida_jefe(noche: int, jugadores: int) -> int:
	var duraciones: Dictionary = progresion["escalado"]["duracion_jefe"]
	var mejor := 60.0
	var dist := INF
	for k in duraciones.keys():
		var d := absf(float(k) - noche)
		if d < dist:
			dist = d
			mejor = float(duraciones[k])
	return int(dps_esperado(noche) * (1.0 + _esc("vida_jefe_por_jugador") * (maxi(1, jugadores) - 1)) * mejor * 0.6)

func intervalo_spawn(noche: int) -> float:
	return maxf(_esc("intervalo_spawn_minimo"), float(noche_campana(noche).get("intervalo", 1.0)))

func oro_por_baja(tipo: String, noche: int) -> int:
	var z := zombie(tipo)
	return int(float(z["oro_base"]) * randf_range(0.8, 1.2) * (1.0 + _esc("oro_por_noche") * (noche - 1)))

# ----------------------------------------------------------
# PROGRESIÓN DEL JUGADOR (Manual v3 §5)
# ----------------------------------------------------------
func xp_para_nivel(nivel: int) -> int:
	return int(progresion["xp_base_nivel"]) + int(progresion["xp_por_nivel"]) * nivel

# XP que recibe CADA jugador por una baja. Dividida por el mismo factor que
# multiplica el presupuesto, para que solo o con cuatro se suba al mismo ritmo.
func xp_por_baja(tipo: String, jugadores: int) -> int:
	var costo := float(zombie(tipo)["costo"])
	return maxi(1, int(costo * float(progresion["xp_por_costo_baja"]) / (1.0 + _esc("presupuesto_por_jugador") * (maxi(1, jugadores) - 1))))

func xp_por_noche(noche: int) -> int:
	return int(progresion["xp_noche_base"]) + int(progresion["xp_noche_por_noche"]) * noche

func stat(nombre: String) -> Dictionary:
	return progresion["stats"][nombre]

# ----------------------------------------------------------
# ESTRUCTURAS Y LOOT
# ----------------------------------------------------------
func estructura(id: String) -> Dictionary:
	return estructuras.get(id, {})

func loot(clave: String):
	return progresion["loot"][clave]

func tier_plano_maximo(noche: int) -> int:
	var tier := 1
	for par in progresion["loot"]["tier_plano_por_noche"]:
		if noche >= int(par[0]):
			tier = int(par[1])
	return tier
