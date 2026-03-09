extends Resource
# class_name hace que Godot lo reconozca como un nuevo tipo de archivo oficial
class_name ArmaData

@export var nombre: String = "Pistola"
@export var dano: int = 10
@export var cadencia: float = 3.0 # Balas por segundo (bps)
@export var tamano_cargador: int = 12
@export var tiempo_recarga: float = 1.2
@export var balas_por_disparo: int = 1 # 1 para pistola, 6 para escopeta
@export var dispersion: float = 0.0 # Grados de desvío (Spread)
