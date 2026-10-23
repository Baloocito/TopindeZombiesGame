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
- `scenes/` escenas (menú, lobby, mundo, pausa)
- `scripts/` lógica en GDScript
- `prefabs/` jugador, zombie, estructuras, pickups
- `materials/` armas y materiales
- `assets/` imágenes y modelos

El manual de diseño vigente (v3) es la fuente de verdad del balance y de las fases de desarrollo.
