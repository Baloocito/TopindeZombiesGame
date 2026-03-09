extends Camera3D

@export var objetivo: Node3D
@export var velocidad_suavizado: float = 5.0

# 📦 Márgenes asimétricos para la "Caja Invisible"
@export var margen_izquierdo: float = 3.0
@export var margen_derecho: float = 3.0
@export var margen_arriba: float = 3.0  # Movimiento hacia el "norte" (-Z)
@export var margen_abajo: float = 1.0   # Movimiento hacia el "sur" (+Z). ¡MÁS PEQUEÑO!

var offset: Vector3
var punto_enfoque: Vector3

func _ready():
	if objetivo:
		offset = global_position - objetivo.global_position
		punto_enfoque = objetivo.global_position

func _physics_process(delta):
	if not objetivo:
		return

	var pos_jugador = objetivo.global_position

	# 1. Eje X (Izquierda / Derecha)
	if pos_jugador.x < punto_enfoque.x - margen_izquierdo:
		punto_enfoque.x = pos_jugador.x + margen_izquierdo
	elif pos_jugador.x > punto_enfoque.x + margen_derecho:
		punto_enfoque.x = pos_jugador.x - margen_derecho

	# 2. Eje Z (Arriba / Abajo)
	# Nota: En Godot 3D, el "Norte" (arriba en la pantalla) es -Z, y el "Sur" (abajo) es +Z.
	if pos_jugador.z < punto_enfoque.z - margen_arriba:
		punto_enfoque.z = pos_jugador.z + margen_arriba
	elif pos_jugador.z > punto_enfoque.z + margen_abajo:
		punto_enfoque.z = pos_jugador.z - margen_abajo

	# 3. Interpolar la cámara hacia el nuevo punto de enfoque
	var posicion_final = punto_enfoque + offset
	global_position = global_position.lerp(posicion_final, velocidad_suavizado * delta)
