extends EstructuraBase
# Barricada genérica (madera, púas, barril, acero, eléctrico).
# Pendiente Fase 2: comportamiento propio de cada tipo (Manual v3 §9).

var tween_dano: Tween

func al_recibir_dano() -> void:
	if tween_dano: tween_dano.kill()
	tween_dano = create_tween()
	var proporcion = max(0.4, float(salud_actual) / float(salud_maxima))
	var escala_base = Vector3.ONE * (0.6 + (0.4 * proporcion))
	tween_dano.tween_property(self, "scale", escala_base * 0.8, 0.05)
	tween_dano.tween_property(self, "scale", escala_base, 0.15).set_trans(Tween.TRANS_BOUNCE)
