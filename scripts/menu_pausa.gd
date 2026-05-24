extends CanvasLayer

var en_partida_online: bool = false 

# Referencia a nuestro nuevo cartel de próximamente
@onready var panel_opciones = $PanelOpciones 

func _ready():
	visible = false
	if panel_opciones:
		panel_opciones.visible = false # Nos aseguramos de que arranque apagado

func alternar_pausa():
	visible = !visible
	
	if visible:
		if not en_partida_online:
			get_tree().paused = true 
	else:
		get_tree().paused = false 
		# Si quitamos la pausa, escondemos las opciones por si quedaron abiertas
		if panel_opciones: 
			panel_opciones.visible = false 

# --- SEÑALES DE LOS BOTONES ---

func _on_boton_reanudar_pressed():
	alternar_pausa()

func _on_boton_opciones_pressed():
	# En lugar de solo imprimir, mostramos el cartel
	if panel_opciones:
		panel_opciones.visible = true 

func _on_boton_cerrar_opciones_pressed():
	# El botón de "Cerrar" dentro del cartel
	if panel_opciones:
		panel_opciones.visible = false

func _on_boton_abandonar_pressed():
	get_tree().paused = false 
	get_tree().change_scene_to_file("res://scenes/menu_principal.tscn")

# Si este es el botón táctil del HUD de tu juego, debe llamar a alternar_pausa()
func _on_boton_pausa_tactil_pressed() -> void:
	alternar_pausa()
