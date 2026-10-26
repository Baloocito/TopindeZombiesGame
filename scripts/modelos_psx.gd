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
