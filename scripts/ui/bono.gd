class_name Bono
# ==========================================================
# CUÁNTO MEJORÓ ALGO (para que la mejora se sienta)
# ==========================================================
# Muestra un valor con lo ganado respecto de su base entre paréntesis:
#   Bono.bb(14, 10)                    -> "14 [color=verde](+4)[/color]"
#   Bono.bb(1.6, 2.5, 2, " s", true)   -> "1.60 s [color=verde](−0.90 s)[/color]"
# menor_es_mejor = true para tiempos (recarga): bajar es mejora.

const VERDE := "#4ade80"
const ROJO := "#f87171"

static func _num(v: float, dec: int) -> String:
	return str(int(round(v))) if dec == 0 else ("%." + str(dec) + "f") % v

static func diferencia(actual: float, base: float, dec: int = 0, sufijo: String = "", menor_es_mejor: bool = false) -> String:
	var d := actual - base
	var umbral := 0.5 if dec == 0 else 0.5 * pow(10.0, -dec)
	if absf(d) < umbral: return ""
	var signo := "+" if d > 0 else "−"
	return "(%s%s%s)" % [signo, _num(absf(d), dec), sufijo]

# Texto con BBCode para un RichTextLabel.
static func bb(actual: float, base: float, dec: int = 0, sufijo: String = "", menor_es_mejor: bool = false) -> String:
	var txt := _num(actual, dec) + sufijo
	var dif := diferencia(actual, base, dec, sufijo, menor_es_mejor)
	if dif == "": return txt
	var mejor := (actual < base) if menor_es_mejor else (actual > base)
	return "%s [color=%s]%s[/color]" % [txt, VERDE if mejor else ROJO, dif]

# Etiqueta lista para usar en los menús (RichTextLabel que ajusta su alto).
static func etiqueta(bbcode: String, centrado: bool = true) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.text = ("[center]%s[/center]" % bbcode) if centrado else bbcode
	return r

# Resumen de un arma contra sus valores de fábrica (data/armas.json).
static func arma(a: ArmaData) -> String:
	var b: ArmaData = Balance.crear_arma(a.id) if a.id != "" else null
	if not b: b = a
	var lineas := [
		"Daño: " + bb(a.dano, b.dano) + ("  ×%d" % a.balas_por_disparo if a.balas_por_disparo > 1 else ""),
		"Cadencia: " + bb(a.cadencia, b.cadencia, 1, " bps"),
		"Cargador: " + bb(a.tamano_cargador, b.tamano_cargador, 0, " balas"),
		"Recarga: " + bb(a.tiempo_recarga, b.tiempo_recarga, 2, " s", true),
		"Munición: " + a.tipo_municion,
	]
	return "\n".join(lineas)
