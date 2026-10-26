extends Resource
class_name ArmaData
# Estadísticas de un arma. No se guardan como .tres: se crean desde
# data/armas.json con Balance.crear_arma(id), así cada jugador tiene su propia
# copia y el balance vive en un solo lugar.

@export var id: String = ""
@export var nombre: String = "Nueva Arma"
@export_enum("Ligera", "Pesada", "Energia") var tipo_municion: String = "Ligera"

@export var dano: int = 10
@export var cadencia: float = 3.0       # balas por segundo
@export var tamano_cargador: int = 12
@export var tiempo_recarga: float = 1.5
@export var balas_por_disparo: int = 1  # 6 para la escopeta
@export var dispersion: float = 0.0     # en grados

@export var dano_area: int = 0          # Ballesta y Lanzagranadas (pendiente: aún no lo aplica bala.gd)
@export var penetra_enemigos: bool = false
@export var mejoras: int = 0           # veces que se forjó en la Mesa de Trabajo

# "Escopeta Vieja +2" si ya se mejoró.
func nombre_con_nivel() -> String:
	return nombre + (" +%d" % mejoras if mejoras > 0 else "")

# Para mandar un arma por RPC (un Resource no viaja por red).
func a_diccionario() -> Dictionary:
	return {"id": id, "nombre": nombre, "tipo_municion": tipo_municion, "dano": dano,
		"cadencia": cadencia, "tamano_cargador": tamano_cargador, "tiempo_recarga": tiempo_recarga,
		"balas_por_disparo": balas_por_disparo, "dispersion": dispersion,
		"dano_area": dano_area, "penetra_enemigos": penetra_enemigos, "mejoras": mejoras}

static func desde_diccionario(d: Dictionary) -> ArmaData:
	var a := ArmaData.new()
	for clave in d.keys():
		if clave in a: a.set(clave, d[clave])
	return a
