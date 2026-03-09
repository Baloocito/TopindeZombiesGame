extends Area3D

@export var velocidad: float = 20.0
@export var tiempo_vida: float = 2.0 

# ¡NUEVO! La variable que el jugador modificará justo antes de disparar
var dano: int = 10 

func _ready():
	# Conectamos la señal de colisión
	body_entered.connect(_al_chocar)
	
	# Temporizador de destrucción automática (para no saturar la memoria)
	await get_tree().create_timer(tiempo_vida).timeout
	queue_free() 

func _physics_process(delta):
	global_position += transform.basis.z * velocidad * delta

# Esta función se activa cuando la bala toca algo
func _al_chocar(cuerpo: Node3D):
	# 1. ESCUDO: Si tocamos al jugador o a una barricada, la bala sigue de largo (return)
	if cuerpo.is_in_group("jugador") or cuerpo.is_in_group("barricadas"):
		return
		
	# 2. Si tocamos a un enemigo, le hacemos daño
	if cuerpo.is_in_group("enemigos"):
		if cuerpo.has_method("recibir_dano"):
			cuerpo.recibir_dano(dano)
			
	# 3. La bala se destruye (Esto solo pasará si chocó con un enemigo o una pared/suelo)
	queue_free()
