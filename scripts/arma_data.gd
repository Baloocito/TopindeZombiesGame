extends Resource
class_name ArmaData

@export var nombre: String = "Nueva Arma"

# Tipos de munición (Ligera, Pesada, Energía) para las futuras cajas de loot
@export_enum("Ligera", "Pesada", "Energia") var tipo_municion: String = "Ligera"

# Estadísticas de Combate (Tabla GDD)
@export var dano: int = 10
@export var cadencia: float = 3.0 # Balas por segundo (bps)
@export var tamano_cargador: int = 12
@export var tiempo_recarga: float = 1.5

# Atributos Especiales para Escopetas y Miniguns
@export var balas_por_disparo: int = 1 # Pon 6 para la escopeta
@export var dispersion: float = 0.0 # En grados (ej. 5.0 para SMG, 15.0 para Escopeta)

# Atributos Únicos (Para las armas avanzadas de tu tabla)
@export var dano_area: int = 0 # Para Ballesta Explosiva y Lanzagranadas
@export var penetra_enemigos: bool = false # Para el Cañón de Riel
