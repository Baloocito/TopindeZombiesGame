extends CanvasLayer

@onready var panel_opciones = $PanelOpciones 

func _ready():
	visible = false
	if panel_opciones:
		panel_opciones.visible = false 

func alternar_pausa():
	visible = !visible
	
	# Lógica inteligente: 
	# Si es Online, NO detenemos el tiempo del servidor (get_tree().paused = false)
	# Si es un juego local solitario, pausamos todo.
	var es_online = multiplayer.has_multiplayer_peer()
	
	if visible:
		if not es_online:
			get_tree().paused = true 
	else:
		get_tree().paused = false 
		if panel_opciones: 
			panel_opciones.visible = false 

# --- SEÑALES DE LOS BOTONES ---

func _on_boton_reanudar_pressed():
	alternar_pausa()

func _on_boton_opciones_pressed():
	if panel_opciones:
		panel_opciones.visible = true 

func _on_boton_cerrar_opciones_pressed():
	if panel_opciones:
		panel_opciones.visible = false

func _on_boton_abandonar_pressed():
	get_tree().paused = false
	
	# ¡NUEVO! Limpiamos la conexión antes de irnos
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
		
	get_tree().change_scene_to_file("res://scenes/menu_principal.tscn")
