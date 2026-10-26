# Devlog #1 — Topin de Zombies
**Semana del 23 al 26 de octubre de 2026 · TopinGames · @topingames_**

> Un survival cooperativo de zombies para Android y PC, con estética de PlayStation 1,
> 20 noches que se ponen cada vez peores y una última noche que parece imposible.

Este informe cuenta qué avanzó el juego esta semana y deja **todo listo para publicar**:
reels verticales, un carrusel de 7 imágenes y textos para copiar y pegar.

---

## 1. La historia de la semana (para contar en redes)

El proyecto estaba guardado desde junio. Lo retomamos el 23 de octubre y en cuatro días:

| Antes | Ahora |
|---|---|
| Un robot gris en un piso gris | Zombies animados, suelo de tierra, niebla y filtro PS1 |
| Oleadas infinitas sin final | **Campaña de 20 noches** con nombre propio, y modo infinito después |
| Un "jefe" que era un zombie grande | **4 jefes** con ataques avisados, armadura, fases y escudos |
| Mejorabas algo y no se notaba | Cada mejora muestra cuánto subió: `Daño 17 (+5)` |
| Solo joysticks en pantalla | **Táctil, teclado y ratón, y mando**, con teclas reasignables |
| Botones genéricos | Interfaz nueva estilo vidrio, fuente propia e iconos |

**18 commits en una semana · unas 7.000 líneas de código · 4 jefes · 20 noches diseñadas una por una.**

---

## 2. Lo nuevo, explicado para jugadores

### La campaña: 20 noches, la última parece imposible
Cada noche tiene nombre y personalidad: *La Estampida* (todos corren), *Pólvora* (explosivos que
derriban tus muros), *Luna de Sangre* (todos más rápidos y furiosos). La horda llega por oleadas
con pequeños respiros. Desde la noche 16 la dificultad se dispara, y la noche 20 trae al jefe
final con la horda completa encima. Si caen todos, se acaba la partida: no hay segundas
oportunidades. Quien la termine desbloquea las **Noches Eternas**, sin final y con récord.

### Los jefes: avisan en el suelo, castigan fuerte
- **Mosca Titán (noche 5):** armadura frontal, así que de frente casi no le haces daño y tienes que flanquearla. Embiste en línea recta; si choca contra una valla queda aturdida y sin armadura.
- **El Enjambre (noche 10):** un Guardián lento y tres Acechadores que te rodean y saltan por turnos. Si matas primero al Guardián, los otros se enfurecen.
- **Mosca Titán Despertada (noche 15):** más rápida, encadena embestidas, ruge para llamar refuerzos y se regenera si dejas de dispararle.
- **El Hospedero (noche 20), jefe final de 3 fases:**
  - Fase 1: golpes de área y llamadas de zombies.
  - Fase 2: ataduras que te dejan clavado al suelo; en coop solo te salva un compañero.
  - Fase 3: suelo tóxico, un escudo y nodos de energía que hay que romper casi a la vez.

### El look: PlayStation 1 de verdad
Los vértices tiemblan como en la consola original, las texturas se deforman, la imagen baja a
270 líneas con 32 tonos por canal y hay niebla de survival horror. De noche la niebla se cierra
y se enfría. Se puede apagar en Opciones.

### Sentir que mejoras
Las armas suben de nivel (`Escopeta Vieja +3`). Cada valor muestra entre paréntesis cuánto
ganaste, y al mejorar te dice exactamente qué subió: `Daño 12 → 17 (+5)`.

### Juega como quieras
En el celular, joysticks en pantalla con zona de disparo. En PC, apuntas con el ratón y
disparas con clic. Con mando, gatillo derecho para disparar. Todas las teclas y botones se
pueden cambiar en Opciones → Controles.

---

## 3. Material listo para publicar

Todo en esta carpeta. Los videos van **sin audio** a propósito: en TikTok e Instagram conviene
ponerles un sonido en tendencia desde la app.

| Archivo | Formato | Para qué |
|---|---|---|
| `reels/reel_horda.mp4` | 1080×1920, 11 s | Reel / TikTok: la horda de la noche 13 |
| `reels/reel_mosca_titan.mp4` | 1080×1920, 11 s | Reel / TikTok: primer jefe y su embestida |
| `reels/reel_hospedero.mp4` | 1080×1920, 11 s | Reel / TikTok: fase 3 del jefe final |
| `reels/teaser_devlog1.mp4` | 1080×1920, 35 s | TikTok largo: los tres seguidos |
| `carrusel/01` a `07` | 1080×1350 | Carrusel de Instagram (en orden) |
| `capturas/*.jpg` | 1440×648 | Capturas sueltas: historias, X, Reddit, itch.io |

> Los clips se grabaron con un jugador automático (da vueltas y dispara solo). Sirven para
> mostrar el juego, pero el mejor contenido va a ser **tu** partida real, grabada en el celular.

---

## 4. Publicaciones para copiar y pegar

### Reel 1 — La horda (el que más engancha: publicar primero)
**Texto en pantalla (primeros 2 s):** `Noche 13 de 20. Ya no hay orden.`

**Descripción:**
```
Estoy haciendo un juego de zombies con estética de PS1 🧟‍♂️📼
20 noches. Cada una peor que la anterior.
La noche 20 está diseñada para que parezca imposible.

¿Llegarías?

Devlog #1 de Topin de Zombies · Android y PC · coop de 1 a 4
Sígueme para ver cómo avanza 👇

#gamedev #indiedev #godotengine #ps1graphics #zombies #survivalgame #devlog #juegosindie #hechoenchile
```

### Reel 2 — Mosca Titán
**Texto en pantalla:** `El primer jefe tiene armadura frontal. Tienes que rodearlo.`

**Descripción:**
```
La Mosca Titán aparece en la noche 5.
De frente casi no le haces daño 🛡️
Pero si la haces chocar contra una valla… queda aturdida y sin armadura.

Así diseñamos los jefes: siempre avisan, nunca perdonan.

#gamedev #indiedev #bossfight #godot #ps1aesthetic #zombiegame #devlog
```

### Reel 3 — El Hospedero
**Texto en pantalla:** `Jefe final. Fase 3. Rompe los nodos a la vez o vuelve a empezar.`

**Descripción:**
```
El Hospedero es el jefe de la noche 20. Tiene 3 fases:
1️⃣ Golpes de área y refuerzos
2️⃣ Ataduras que te clavan al suelo (en coop solo te salva un amigo)
3️⃣ Suelo tóxico, escudo y nodos que hay que romper casi al mismo tiempo

¿Qué fase te parece más difícil?

#gamedev #indiedev #finalboss #godotengine #ps1style #coopgame #devlog
```

### Carrusel de Instagram
**Descripción:**
```
Devlog #1 de Topin de Zombies 🧟📼

Lo retomé hace una semana y esto es lo que cambió:
➡️ De un robot gris a zombies con estética PS1
➡️ Campaña de 20 noches + modo infinito
➡️ 4 jefes con fases y patrones
➡️ Mejoras que se notan
➡️ Táctil, teclado y ratón, y mando

Lo estoy haciendo solo, con Godot, para Android y PC.
Guárdalo si quieres jugar la demo 🔖

#gamedev #indiedev #godotengine #ps1graphics #lowpoly #zombies #survivalhorror #devlog #indiegame
```

### TikTok largo (teaser)
**Texto en pantalla:** `Llevo 30 años jugando videojuegos. Ahora estoy haciendo el mío.`
```
Topin de Zombies: survival coop con estética de PS1.
20 noches, 4 jefes, y una última noche que parece imposible.
Devlog #1 👇 ¿Qué le agregarías?
#gamedev #indiedev #ps1 #zombies #godot #devlog
```

### Historias de Instagram (3 ideas)
1. Captura `capturas/antes_mundo.jpg` y luego `capturas/ahora_zombies_y_objetos.jpg`, con la encuesta **"¿Notas la diferencia?"**.
2. Carrusel de jefes con la pregunta **"¿Cuál quieres ver en acción?"** (encuesta de 4 opciones).
3. Caja de preguntas: **"¿Qué nombre le pondrías a la noche 21?"**. Las respuestas son contenido para el devlog #2.

---

## 5. Calendario sugerido (una semana)

| Día | Publicar | Dónde |
|---|---|---|
| Lunes | Reel 1, la horda | TikTok + Reels |
| Martes | Historia antes/después con encuesta | Instagram |
| Miércoles | Carrusel completo | Instagram |
| Jueves | Reel 2, Mosca Titán | TikTok + Reels |
| Viernes | Historia de preguntas | Instagram |
| Sábado | Reel 3, Hospedero | TikTok + Reels |
| Domingo | Teaser largo | TikTok |

Responder **todos** los comentarios del primer día: es lo que más ayuda a que el algoritmo lo muestre.

---

## 6. Para conseguir financiamiento

El contenido trae a la gente; falta un lugar donde puedan apoyar. En orden:

1. **Ko-fi:** no cobra comisión sobre las donaciones; solo cobran Stripe o PayPal. Va en la bio de Instagram y TikTok desde el primer post.
2. **Metas visibles:** por ejemplo "Meta 1: animaciones para todos los personajes", "Meta 2: música original". La gente apoya más cuando sabe para qué es.
3. **Demo gratis en itch.io** con "paga lo que quieras" (puede ir con mínimo $0). Es el momento en que más se convierte, porque ya probaron el juego.
4. **Mostrar el avance cada semana:** un devlog por semana con la misma estructura que este.

Qué medir cada semana: seguidores nuevos, reproducciones del mejor reel, clics al link de la bio y
apoyos en Ko-fi. Con eso se ve qué tipo de video funciona y se hace más de ese.

---

## 7. Licencias del material

- **Zombie y objetos** (munición, botiquines, armas): packs con licencia CC0. Se pueden mostrar y usar sin restricciones.
- **Fuente Russo One:** licencia OFL.
- **El pack de personajes PSX** (protagonistas y monstruos nuevos) **no aparece en este material** hasta confirmar su licencia.

---

## 8. Lo que viene (devlog #2)

- Animaciones de Mixamo: zombies que caminan, corren, golpean y mueren; protagonistas con pistola y escopeta.
- Reemplazar la cápsula del jugador por los nuevos personajes.
- Estructuras diferenciadas: púas que ralentizan, cerca eléctrica, barril explosivo.
- Primera demo jugable para itch.io.
