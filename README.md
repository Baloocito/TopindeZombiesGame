# TopinDeZombies

Juego cooperativo (1 a 4 jugadores) de defensa contra zombies con progresión tipo RPG, hecho en **Godot 4.6** por TopinGames.
Objetivo: Android y PC, con controles táctiles, teclado y mouse, y mando.

- Campaña de 20 noches con jefe final, y modo Noches Eternas.
- Cámara 3/4 fija, estilo low-poly PS1–PS2.
- Red: ENet de alto nivel, el anfitrión es la autoridad (puerto en `EstadoPartida.PUERTO_RED`).

## Cómo abrirlo
1. Instalar Godot 4.6.
2. Importar `project.godot`.
3. Ejecutar la escena principal (menú). Para probar el coop en un solo PC: *Depurar > Ejecutar múltiples instancias*.

## Estructura
- `data/` **todo el balance** en JSON (armas, zombies, estructuras, progresión). Para ajustar el juego se edita aquí, no el código.
- `scenes/` escenas (menú, lobby, mundo, pausa)
- `scripts/autoload/` singletons: `Balance` (lee data/), `EstadoPartida` (sesión y red), `GuardadoGlobal` (récords)
- `scripts/base/` clases base: `PickupBase` (objetos recogibles) y `EstructuraBase` (barricadas y torreta)
- `scripts/mundo/` partes de Mundo separadas: `menus_mundo.gd` (panel lateral) y `loot_mundo.gd` (qué cae al morir un zombie)
- `scripts/` resto de la lógica (jugador, zombie, torreta, lobby...)
- `prefabs/` jugador, zombie, estructuras, pickups
- `assets/` imágenes y modelos

## Reglas de red
El anfitrión es la autoridad. Todo lo que cuesta oro o afecta al equipo se pide al servidor con `rpc_id(1, ...)` y él lo reparte. Los objetos recogibles los destruye solo el servidor. Ver el Manual v3 §11.

El manual de diseño vigente (v3) es la fuente de verdad del balance y de las fases de desarrollo.
