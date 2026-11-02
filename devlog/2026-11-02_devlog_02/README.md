# Devlog #2 — Topin de Zombies
**Semana del 27 de octubre al 2 de noviembre de 2026 · TopinGames · @topingames_**

> El juego deja los modelos prestados y estrena **arte propio**: 4 protagonistas, la horda,
> los 4 jefes, 9 armas y 6 defensas, todo diseñado por TopinGames.

Este informe cuenta qué avanzó el juego esta semana y deja **todo listo para publicar**:
6 reels verticales, un teaser largo, un carrusel de 9 imágenes y textos para copiar y pegar.

---

## 1. La historia de la semana (para contar en redes)

En el devlog #1 el juego tenía estilo PS1, pero sus personajes eran de un pack gratuito.
Esta semana todos pasaron a ser diseños propios:

| Antes | Ahora |
|---|---|
| Personajes realistas de un pack gratuito | **4 protagonistas propios** de estilo anime action-RPG |
| Zombies civiles repetidos | **La horda con identidad**: básico, corredor, explosivo y dos tanques |
| Jefes improvisados con modelos genéricos | **Acechador, Guardián, Mosca Titán y El Hospedero** con diseño propio |
| 3 modelos de arma para todo | **9 armas**, cada una con su modelo y su tamaño real en la mano |
| Cajas de colores como defensas | **Vallas de madera y acero, púas, barril, muro eléctrico y torreta** |
| Todos jugaban con el mismo personaje | **Selector de personaje**, sin repetir en coop |
| El mando no funcionaba en los menús | **Mando en todos los menús**, con zona muerta, vibración y modo zurdo |
| Te podías caer al vacío | La arena tiene **baranda** y una red de seguridad |

**9 commits en una semana · 16 modelos animados · 9 armas · 6 defensas · 0 modelos prestados en lo principal.**

### Cómo se hace un personaje (el proceso)
1. **Imagen:** se genera el diseño de frente, en pose A y con fondo liso.
2. **Modelo 3D:** Tripo3D convierte la imagen en un modelo con textura.
3. **Esqueleto:** Mixamo le pone los huesos de forma automática.
4. **Al juego:** Godot le aplica las animaciones (correr, disparar, morir…) y el filtro PS1.

Ese proceso es el reel **"De la imagen al juego"**, el mejor para contar la historia del proyecto.

---

## 2. Lo nuevo, explicado para jugadores

### Elige con quién jugar
**Leo** (líder equilibrado), **Miyuki** (ágil), **Frank** (resistente) y **Momo** (apoyo).
Se eligen en la sala y en coop no se repiten. Los primeros diseños de Leo, Miyuki y Momo
también se pueden elegir.

### La horda y los jefes, con cara propia
Cada zombie se reconoce de lejos: el corredor amarillo, el explosivo hinchado y el tanque
blindado. Los jefes —el Acechador, el Guardián, la Mosca Titán y El Hospedero— tienen un
diseño hecho para su forma de pelear.

### 9 armas que se ven en la mano
Pistola 9mm, rifle de clavos, SMG, escopeta, rifle de caza, ballesta explosiva,
lanzallamas (con el tanque en la espalda), minigun y cañón de riel. Las grandes se
sostienen con las dos manos.

### Defensas que se ven como lo que son
De día construyes vallas, púas, barriles explosivos, muros de acero y eléctricos, y torretas
que giran solas hacia el zombie más cercano.

### Juega con mando de verdad
El mando funciona en todos los menús: muestra un marco dorado sobre el botón elegido y
Select abre los menús del día. En Opciones se ajustan la zona muerta, el disparo con el stick,
el apuntado asistido, la vibración y el modo zurdo.

### Y además
- Las partidas de la misma Wi-Fi aparecen solas en el lobby.
- Los personajes giran sobre su propio eje.
- Nadie se cae de la arena.

---

## 3. Material listo para publicar

Los videos van **sin audio** a propósito: en TikTok e Instagram conviene ponerles un sonido
en tendencia desde la app.

| Archivo | Formato | Para qué |
|---|---|---|
| `reels/reel_imagen_al_juego.mp4` | 1080×1920, 14 s | **Publicar primero.** Concepto → modelo 3D animado |
| `reels/reel_arsenal.mp4` | 1080×1920, 13 s | Las 9 armas, una tras otra |
| `reels/reel_enjambre.mp4` | 1080×1920, 11 s | Jefe de la noche 10: Guardián y Acechadores |
| `reels/reel_defensas.mp4` | 1080×1920, 11 s | La base con las 6 defensas |
| `reels/reel_hospedero.mp4` | 1080×1920, 11 s | El jefe final |
| `reels/reel_horda.mp4` | 1080×1920, 11 s | Noche 13 con la horda nueva |
| `reels/teaser_devlog2.mp4` | 1080×1920, 62 s | TikTok largo: cinco reels seguidos |
| `carrusel/01` a `09` | 1080×1350 | Carrusel de Instagram (en orden) |
| `capturas/*.jpg` | varios | Historias, X, Reddit, itch.io |

> Los clips se grabaron con el jugador automático de `herramientas/devlog/`. Tu partida real
> grabada en el celular sigue siendo el mejor contenido: úsala si tienes una buena.

### Calendario sugerido
| Día | Publicación |
|---|---|
| Lunes | Reel "De la imagen al juego" (Instagram + TikTok) |
| Martes | Carrusel en Instagram · Historia con la encuesta "¿Cuál elegirías?" |
| Miércoles | Reel del arsenal |
| Jueves | Reel del Enjambre |
| Viernes | Reel de defensas |
| Sábado | Teaser largo en TikTok |
| Domingo | Reel del Hospedero o de la horda + responder comentarios |

---

## 4. Publicaciones para copiar y pegar

### Reel 1 — De la imagen al juego (el más fuerte: publicar primero)
**Texto en pantalla (primeros 2 s):** `Así diseño los personajes de mi juego`

**Descripción:**
```
De una imagen a un personaje que corre, dispara y muere en mi juego 🧟‍♂️🎮

1️⃣ Diseño la imagen
2️⃣ La paso a 3D
3️⃣ Le pongo esqueleto y animaciones
4️⃣ Entra al juego con filtro de PS1

Topin de Zombies · Devlog #2 · Android y PC · coop de 1 a 4
¿Con cuál jugarías? 👇

#gamedev #indiedev #godotengine #3dmodeling #mixamo #ps1graphics #devlog #juegosindie #hechoenchile
```

### Reel 2 — Arsenal
**Texto en pantalla:** `9 armas. ¿Cuál es la tuya?`
```
Pistola, clavos, SMG, escopeta, rifle de caza, ballesta explosiva,
lanzallamas, minigun y cañón de riel 🔫🔥⚡

Cada una con su modelo y su tamaño real en la mano.
Comenta tu favorita 👇

#gamedev #indiedev #godot #weapons #zombiegame #ps1aesthetic #devlog
```

### Reel 3 — El Enjambre
**Texto en pantalla:** `Noche 10. No viene solo.`
```
El Guardián es lento… pero trae a sus Acechadores.
Te rodean, saltan por turnos y, si matas al Guardián primero, se enfurecen 😈

Los jefes siempre avisan en el suelo. Nunca perdonan.

#gamedev #indiedev #bossfight #godotengine #coopgame #zombies #devlog
```

### Reel 4 — Defensas
**Texto en pantalla:** `De día construyes. De noche resistes.`
```
Vallas, púas, barriles explosivos, muros de acero y eléctricos, y torretas que apuntan solas 🛠️

¿Qué pondrías primero en tu base?

#gamedev #indiedev #towerdefense #survivalgame #godot #ps1graphics #devlog
```

### Reel 5 — El Hospedero
**Texto en pantalla:** `El jefe final ya tiene cara.`
```
El Hospedero espera en la noche 20 🟣
3 fases, ataduras que te clavan al suelo y un escudo que solo cae si rompen los nodos a la vez.

¿Lo intentarías solo o en coop?

#gamedev #indiedev #finalboss #godotengine #zombiegame #devlog
```

### Reel 6 — La horda
**Texto en pantalla:** `Noche 13 de 20.`
```
La horda ahora tiene identidad: corredores, explosivos y tanques que se reconocen de lejos 🧟🧟‍♀️🧟‍♂️

#gamedev #indiedev #zombies #hordemode #godot #ps1style #devlog
```

### Carrusel de Instagram
```
Devlog #2 de Topin de Zombies 🧟📼

Esta semana el juego estrenó arte propio:
➡️ 4 protagonistas (Leo, Miyuki, Frank y Momo)
➡️ La horda y los 4 jefes rediseñados
➡️ 9 armas que se ven en la mano
➡️ 6 defensas para tu base
➡️ Mando en todos los menús

Lo hago solo, con Godot, para Android y PC.
Guárdalo si quieres jugar la demo 🔖 ¿Cuál elegirías? 👇

#gamedev #indiedev #godotengine #ps1graphics #lowpoly #zombies #survivalhorror #devlog #indiegame
```

### TikTok largo (teaser)
**Texto en pantalla:** `Una semana haciendo el arte de mi juego de zombies`
```
Diseños, 3D, esqueletos, animaciones y al juego. Todo en una semana 🧟‍♂️
Devlog #2 de Topin de Zombies.

Sígueme para ver cómo sigue 👀

#gamedev #indiedev #godot #devlog #zombiegame #ps1 #fyp
```

### Historia de Instagram (encuesta)
Usa `carrusel/04_protagonistas.jpg` con el sticker **Cuestionario** (permite 4 opciones):
**"¿Con quién juegas la noche 20?"** → Leo · Miyuki · Frank · Momo.

---

## 5. Para el devlog #3
- Grabar una partida real en el celular (coop si se puede).
- Más variantes del zombie básico, para que la horda no se vea repetida.
- Un modelo propio para el lanzagranadas.
- Publicar la demo en itch.io con el enlace en la bio.
