extends CanvasLayer

@onready var panel_opciones = $PanelOpciones 

func _ready():
	visible = false
	if panel_opciones:
		panel_opciones.visible = false 
	for b in $VBoxContainer.get_children():
		if b is BaseButton: EstiloUI.agregar_rebote(b)
	_agregar_opcion_ps1()

# Opciones > Estilo retro PS1 (se guarda en user://ajustes.cfg).
func _agregar_opcion_ps1():
	if not panel_opciones: return
	var c := CheckButton.new()
	c.name = "OpcionPS1"
	c.text = "Estilo retro PS1"
	c.button_pressed = PS1.activo
	c.position = Vector2(246, 130)
	c.custom_minimum_size = Vector2(260, 52)
	var titulo := panel_opciones.get_node_or_null("Label") as Label
	if titulo:
		titulo.text = "OPCIONES"
		titulo.position = Vector2(192, 40)
		titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.toggled.connect(func(v): PS1.alternar(v))
	panel_opciones.add_child(c)

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
