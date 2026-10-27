# Modelos KH (arte propio de TopinGames)

Personajes diseñados por TopinGames: imagen generada en Tripo3D, convertida a 3D
en Tripo y con esqueleto automático de Mixamo (huesos `mixamorig_*`). Las
animaciones de `assets/animaciones/mixamo` les sirven a todos.

| Carpeta | Uso en el juego |
| --- | --- |
| `leo/`, `frank/`, `miyuki/`, `momo/` | Protagonistas (selector del lobby, `data/personajes.json` → `protagonistas`) |
| `tanque/` | Zombie tanque |

## Agregar uno nuevo

1. En Tripo exporta el modelo **sin rig** (FBX u OBJ). Si el archivo ya trae
   esqueleto, Mixamo responde "unable to map your existing skeleton".
2. Súbelo a Mixamo, auto-rig, descarga **FBX Binary, With Skin, T-pose**.
3. Crea `KH/<nombre>/<nombre>.fbx` y pon al lado la textura de color
   (`*_BaseColor.png`) como `<nombre>.png`. Los mapas metallic/roughness/normal
   no hacen falta (van a `_extra/`, que no se sube al repositorio).
4. Agrega la ruta `KH/<nombre>/<nombre>` al rol que corresponda en
   `data/personajes.json`.
5. Agrega el modelo a la lista de `herramientas/mallas/reducir_mallas.gd` y córrelo:
   `godot --headless -s herramientas/mallas/reducir_mallas.gd`.
   Tripo entrega ~50.000 triángulos; el juego usa la versión `_lp.res`
   (~6.000 protagonistas, ~3.000 zombies).

`sin_rig/` guarda los diseños que todavía no pasaron por Mixamo (Godot los ignora).
