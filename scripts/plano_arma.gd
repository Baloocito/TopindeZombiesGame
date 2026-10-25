extends PickupBase
# Plano de arma. El servidor elige el arma ANTES de agregarlo al mundo; el
# id y el tier viajan con el spawn (MultiplayerSynchronizer del prefab).
# Antes solo el servidor sabía qué arma traía, y el cliente nunca podía
# recogerlo (su copia tenía el id vacío).

const COLORES_TIER := {1: Color(0.8, 0.8, 0.8), 2: Color(0.1, 0.9, 0.1), 3: Color(0.1, 0.5, 1.0), 4: Color(0.9, 0.2, 0.9)}

@export var arma_id_contenida: String = ""
@export var tier_del_plano: int = 1

var tiempo_flotacion: float = 0.0

func _ready():
	super._ready()
	configurar_color_por_tier()

func _process(delta):
	tiempo_flotacion += delta
	position.y += sin(tiempo_flotacion * 4.0) * 0.005
	rotation.y += 2.0 * delta

# Devuelve false si no hay armas válidas (el llamador no debe agregarlo).
func generar_plano(tier_maximo: int, es_elite: bool) -> bool:
	var validas := []
	for id in Balance.ids_armas():
		if id == Balance.progresion["arma_inicial"]: continue
		var tier := Balance.tier_arma(id)
		if (es_elite and tier == tier_maximo) or (not es_elite and tier <= tier_maximo):
			validas.append(id)
	if validas.is_empty(): return false
	arma_id_contenida = validas.pick_random()
	tier_del_plano = Balance.tier_arma(arma_id_contenida)
	return true

func configurar_color_por_tier():
	var color: Color = COLORES_TIER.get(tier_del_plano, Color.WHITE)
	if has_node("OmniLight3D"): $OmniLight3D.light_color = color
	if has_node("MeshInstance3D"):
		# El material del prefab está en la ranura de superficie 0 (antes se
		# buscaba en material_override, que está vacío, y el color nunca cambiaba).
		var malla: MeshInstance3D = $MeshInstance3D
		var mat := malla.get_surface_override_material(0)
		if mat:
			mat = mat.duplicate()
			mat.albedo_color = color
			mat.emission = color * 3.0
			malla.set_surface_override_material(0, mat)

func al_recoger_servidor(_id_remitente: int) -> void:
	var m = mundo()
	if arma_id_contenida != "" and m and m.has_method("agregar_plano_para_todos"):
		m.agregar_plano_para_todos.rpc(arma_id_contenida)
