extends EstructuraBase
# Barricada genérica (madera, púas, barril, acero, eléctrico).
# Pendiente Fase 2: comportamiento propio de cada tipo (Manual v3 §9).

var tween_dano: Tween

# Ancho del modelo propio (assets/modelos/estructuras_kh) en metros. La
# casilla y la colisión siguen siendo de 2 x 2 m.
const ANCHO_MODELO := {"madera": 2.0, "acero": 2.0, "electrico": 2.0, "puas": 2.0, "barril": 0.95}

func _ready():
	super._ready()
	_poner_modelo()

func _poner_modelo():
	if not ModelosPSX.tiene_estructura(tipo_estructura): return
	var caja := get_node_or_null("MeshInstance3D") as MeshInstance3D
	var base_y := -0.5
	if caja:
		caja.visible = false
		if caja.mesh is BoxMesh: base_y = caja.position.y - (caja.mesh as BoxMesh).size.y * 0.5
	var m := ModelosPSX.estructura(tipo_estructura, float(ANCHO_MODELO.get(tipo_estructura, 2.0)))
	m.position.y = base_y
	add_child(m)

func al_recibir_dano() -> void:
	if tween_dano: tween_dano.kill()
	tween_dano = create_tween()
	var proporcion = max(0.4, float(salud_actual) / float(salud_maxima))
	var escala_base = Vector3.ONE * (0.6 + (0.4 * proporcion))
	tween_dano.tween_property(self, "scale", escala_base * 0.8, 0.05)
	tween_dano.tween_property(self, "scale", escala_base, 0.15).set_trans(Tween.TRANS_BOUNCE)
