extends JefeIA
# ==========================================================
# EL ENJAMBRE (noche 10): el GUARDIÁN
# ==========================================================
# El que tanquea: lento, mucha vida (40 % del Enjambre), golpe sísmico y un
# pisotón en cadena (tres círculos que avanzan hacia el jugador). Mientras
# vive, los Acechadores cazan con calma; si cae, se enfurecen.

var _dir := Vector3.ZERO
var _paso := 0
var _t_paso := 0.0

func al_iniciar():
	usar("sismo", 2.5)
	usar("pisoton", 5.0)

func elegir_ataque(dist: float) -> String:
	if listo("sismo") and dist < 4.5: return "sismo"
	if listo("pisoton") and dist < 12.0: return "pisoton"
	return ""

func al_avisar(nombre: String):
	match nombre:
		"sismo":
			datos_ataque.aviso = 1.0
			avisar_circulo(z.global_position, 4.2, 1.0)
			usar("sismo", 5.0)
		"pisoton":
			mirar_a(objetivo.global_position)
			_dir = direccion_plana(objetivo.global_position)
			datos_ataque.aviso = 0.5
			for i in 3:
				avisar_circulo(z.global_position + _dir * (3.0 + 3.0 * i), 2.0, 0.6 + 0.35 * i)
			usar("pisoton", 9.0)

func al_ejecutar(nombre: String):
	match nombre:
		"sismo": golpe_area(z.global_position, 4.2, 1.5)
		"pisoton":
			_paso = 0
			_t_paso = 0.1

func procesar_accion(delta: float) -> bool:
	if ataque != "pisoton": return true
	_t_paso -= delta
	if _t_paso <= 0.0:
		golpe_area(z.global_position + _dir * (3.0 + 3.0 * _paso), 2.0, 1.1)
		_paso += 1
		_t_paso = 0.35
	return _paso >= 3

func duracion_recuperacion(nombre: String) -> float:
	return 1.4 if nombre == "sismo" else 1.0
