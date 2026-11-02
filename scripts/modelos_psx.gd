class_name ModelosPSX
# ==========================================================
# MODELOS 3D DEL JUEGO (packs CC0, ver assets/modelos/*/LICENCIA.txt)
# ==========================================================
# Un solo lugar para pedir modelos, así cambiar un pack no obliga a tocar
# cada prefab:
#   ModelosPSX.zombie()                   -> zombie animado (caminata en bucle)
#   ModelosPSX.objeto("Shotgun", 0.9)     -> un objeto del PSX Asset Pack 3,
#                                            escalado a 0,9 m en su lado más largo
# Objetos del pack: Ammo_box, Ammo_box_9mm, Open_ammo_box_9mm,
# First_aid_kit_variant_one, Old_military_first_aid_kit, Health_drink, Knife,
# Molotov, Old_military_flashlight, Pistol_variant_one, Pistol_variant_two,
# Lower_poly_pistol_variant, Shotgun, Radio_receiver, Radio_receiver_two,
# Voice_recorder.

const ESCENA_ZOMBIE := preload("res://assets/modelos/zombie_psx/zombie_psx.glb")
const ESCENA_PACK := preload("res://assets/modelos/psx_pack3/psx_pack3.glb")
const ALTO_ZOMBIE := 1.85

static var _pack: Node3D = null

# Zombie con su animación en bucle. Cada uno empieza en un punto distinto
# del ciclo para que la horda no camine sincronizada.
static func zombie(velocidad_anim: float = 1.0) -> Node3D:
	var z := ESCENA_ZOMBIE.instantiate() as Node3D
	z.rotation.y = PI  # el modelo mira a +Z; en Godot "adelante" es -Z
	z.scale = Vector3.ONE * (ALTO_ZOMBIE / 1.62)
	var ap := z.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and not ap.get_animation_list().is_empty():
		var nombre: StringName = ap.get_animation_list()[0]
		var anim := ap.get_animation(nombre)
		anim.loop_mode = Animation.LOOP_LINEAR
		ap.speed_scale = velocidad_anim
		ap.play(nombre)
		ap.seek(randf() * anim.length, true)
	return z

static func objeto(nombre: String, tamano: float) -> Node3D:
	if _pack == null:
		_pack = ESCENA_PACK.instantiate() as Node3D
	var original := _pack.find_child(nombre, true, false) as MeshInstance3D
	var raiz := Node3D.new()
	raiz.name = "Modelo"
	if not original: return raiz
	var malla := MeshInstance3D.new()
	malla.mesh = original.mesh
	for i in original.get_surface_override_material_count():
		malla.set_surface_override_material(i, original.get_surface_override_material(i))
	var caja := original.mesh.get_aabb()
	var lado := maxf(caja.size.x, maxf(caja.size.y, caja.size.z))
	var escala := tamano / maxf(0.001, lado)
	malla.scale = Vector3.ONE * escala
	# Centrado en X/Z y apoyado en el suelo (y = 0).
	var centro := caja.get_center()
	malla.position = Vector3(-centro.x, -caja.position.y, -centro.z) * escala
	raiz.add_child(malla)
	return raiz

# ----------------------------------------------------------
# PERSONAJES (assets/modelos/personajes_psx, roles en data/personajes.json)
# ----------------------------------------------------------
const RUTA_PERSONAJES := "res://assets/modelos/personajes_psx/"
const ALTO_PERSONAJE := 1.8
static var _roles: Dictionary = {}

static func roles() -> Dictionary:
	if _roles.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/personajes.json"))
		if typeof(d) == TYPE_DICTIONARY: _roles = d.get("roles", {})
	return _roles

# Un modelo del rol (al azar si hay varios; `indice` >= 0 elige uno fijo).
static func nombre_para_rol(rol: String, indice: int = -1) -> String:
	var lista: Array = roles().get(rol, [])
	if lista.is_empty(): return ""
	return lista[indice % lista.size()] if indice >= 0 else lista.pick_random()

# Instancia el personaje con su textura, escalado a ALTO_PERSONAJE y mirando
# hacia -Z. Las animaciones de Mixamo se le agregan aparte (mismo esqueleto).
# `nombre` es un modelo del pack PSX ("Character_29") o una ruta dentro de
# assets/modelos sin extensión ("KH/leo/leo"): el .fbx y su .png al lado.
static func ruta_modelo(nombre: String) -> String:
	if "/" in nombre: return "res://assets/modelos/" + nombre
	return RUTA_PERSONAJES + "modelos/" + nombre

static func personaje(nombre: String) -> Node3D:
	var base := ruta_modelo(nombre)
	# .fbx (Mixamo) o .glb (Tripo con esqueleto de Mixamo), con la textura .png al lado.
	var escena = load(base + ".fbx") if ResourceLoader.exists(base + ".fbx") else load(base + ".glb")
	if not escena: return Node3D.new()
	var p := escena.instantiate() as Node3D
	var tex = load(base + ".png")
	# Versión con menos polígonos (herramientas/mallas/reducir_mallas.gd).
	if ResourceLoader.exists(base + "_lp.res"):
		var lp = load(base + "_lp.res")
		for m in p.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).mesh = lp
			break
	var caja := AABB()
	var primera := true
	for m in p.find_children("*", "MeshInstance3D", true, false):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		(m as MeshInstance3D).material_override = mat
		var b: AABB = (m as MeshInstance3D).get_aabb()
		caja = b if primera else caja.merge(b)
		primera = false
	# Medida real del modelo: una malla con piel se dibuja en el espacio del
	# esqueleto (pose de reposo × matriz de unión), no en el de su nodo.
	var alto := caja.size.y
	var piso := caja.position.y
	var mallas := p.find_children("*", "MeshInstance3D", true, false)
	var esq := p.find_child("Skeleton3D", true, false) as Skeleton3D
	if esq and not mallas.is_empty() and (mallas[0] as MeshInstance3D).skin:
		var mi := mallas[0] as MeshInstance3D
		var piel := mi.skin
		var hueso := piel.get_bind_bone(0)
		if hueso < 0: hueso = esq.find_bone(piel.get_bind_name(0))
		if hueso >= 0:
			var t := Transform3D()
			var n: Node = esq
			while n and n != p:
				t = (n as Node3D).transform * t
				n = n.get_parent()
			var en_p: AABB = (t * esq.get_bone_global_rest(hueso) * piel.get_bind_pose(0)) * mi.get_aabb()
			alto = en_p.size.y
			piso = en_p.position.y
	var raiz := Node3D.new()
	raiz.name = "Personaje"
	var escala := ALTO_PERSONAJE / maxf(0.01, alto)
	p.scale = Vector3.ONE * escala
	p.position = Vector3(0, -piso * escala, 0)
	# Los .fbx de Mixamo llegan mirando a -Z; los .glb ya miran a +Z (el
	# frente del personaje en el juego).
	p.rotation.y = PI if ResourceLoader.exists(base + ".fbx") else 0.0
	raiz.add_child(p)
	return raiz

# ----------------------------------------------------------
# ARMAS PROPIAS (assets/modelos/armas_kh, hechas en Tripo por TopinGames)
# ----------------------------------------------------------
# Por arma: giro en Y que lleva el cañón del modelo original a -Z, largo real
# en metros, si se sostiene con las dos manos y dónde va la mano (fracción
# del largo medida desde atrás).
const RUTA_ARMAS := "res://assets/modelos/armas_kh/"
const ARMAS := {
	"pistola":     {"giro": 90.0,  "largo": 0.26, "dos_manos": false, "mano": 0.25},
	"clavos":      {"giro": -90.0, "largo": 0.38, "dos_manos": false, "mano": 0.45},
	"smg":         {"giro": -90.0, "largo": 0.6,  "dos_manos": true,  "mano": 0.4},
	"escopeta":    {"giro": -90.0, "largo": 0.9,  "dos_manos": true,  "mano": 0.3},
	"rifle_caza":  {"giro": 90.0,  "largo": 1.1,  "dos_manos": true,  "mano": 0.3},
	"ballesta":    {"giro": 180.0, "largo": 0.75, "dos_manos": true,  "mano": 0.3},
	"lanzallamas": {"giro": -90.0, "largo": 0.95, "dos_manos": true,  "mano": 0.3},
	"minigun":     {"giro": -90.0, "largo": 0.95, "dos_manos": true,  "mano": 0.35},
	"riel":        {"giro": 180.0, "largo": 0.9,  "dos_manos": true,  "mano": 0.3},
}

static func tiene_arma(id: String) -> bool:
	return ARMAS.has(id) and ResourceLoader.exists(RUTA_ARMAS + id + ".glb")

static func arma_dos_manos(id: String) -> bool:
	return bool(ARMAS.get(id, {}).get("dos_manos", false))

# El arma con el cañón hacia -Z, arriba +Y y la empuñadura en el origen.
# `largo` < 0 usa el largo real de la tabla.
static func arma(id: String, largo: float = -1.0) -> Node3D:
	var datos: Dictionary = ARMAS.get(id, {"giro": 0.0, "largo": 0.5, "mano": 0.3})
	return _modelo_glb(RUTA_ARMAS + id + ".glb", float(datos.giro), largo if largo > 0.0 else float(datos.largo), float(datos.mano), "largo")

# Modelo .glb girado `giro` grados en Y, escalado para que su lado `medida`
# ("largo" = Z tras el giro, "alto" = Y, "ancho" = X) mida `tamano`, centrado
# en X, apoyado en Y = 0 (o a media altura si es un arma) y con el origen a
# `fraccion_z` del largo contando desde atrás.
static func _modelo_glb(ruta: String, giro: float, tamano: float, fraccion_z: float, medida: String) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Modelo"
	var escena = load(ruta)
	if not escena: return raiz
	var n := escena.instantiate() as Node3D
	var gir := Node3D.new()
	gir.rotation_degrees.y = giro
	gir.add_child(n)
	raiz.add_child(gir)
	# Caja del modelo en el espacio del nodo girado.
	var caja := AABB()
	var primera := true
	var rot := Basis(Vector3.UP, deg_to_rad(giro))
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var t := Transform3D()
		var x: Node = mi
		while x and x != n:
			t = (x as Node3D).transform * t
			x = x.get_parent()
		var b: AABB = Transform3D(rot, Vector3.ZERO) * (t * mi.get_aabb())
		caja = b if primera else caja.merge(b)
		primera = false
	var lado := caja.size.z
	if medida == "alto": lado = caja.size.y
	elif medida == "ancho": lado = maxf(caja.size.x, caja.size.z)
	var escala := tamano / maxf(0.001, lado)
	gir.scale = Vector3.ONE * escala
	var centro := caja.get_center()
	var y := -caja.position.y if medida != "largo" else -centro.y
	var z := -(caja.end.z - caja.size.z * fraccion_z) if medida == "largo" else -centro.z
	gir.position = Vector3(-centro.x, y, z) * escala
	return raiz

# ----------------------------------------------------------
# ESTRUCTURAS PROPIAS (assets/modelos/estructuras_kh)
# ----------------------------------------------------------
const RUTA_ESTRUCTURAS := "res://assets/modelos/estructuras_kh/"

static func tiene_estructura(id: String) -> bool:
	return ResourceLoader.exists(RUTA_ESTRUCTURAS + id + ".glb")

# La estructura apoyada en el suelo, centrada y con su lado más ancho (X o Z)
# midiendo `ancho` metros.
static func estructura(id: String, ancho: float, giro: float = 0.0) -> Node3D:
	return _modelo_glb(RUTA_ESTRUCTURAS + id + ".glb", giro, ancho, 0.5, "ancho")
