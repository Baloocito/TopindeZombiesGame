# Herramientas para grabar material del devlog

Godot ignora esta carpeta (`.gdignore`). Sirve para sacar clips de gameplay sin
tener que jugar a mano: un "jugador demo" da vueltas, apunta al zombie más
cercano y dispara solo, y Godot graba cada cuadro (Movie Maker).

## Grabar un clip

1. Copia `grabar_video.gd` y `grabar_video.tscn` a una carpeta `tools_tmp/` en la raíz del proyecto.
2. Desde la raíz del proyecto:

```
godot --path . --write-movie clip.avi --fixed-fps 30 res://tools_tmp/grabar_video.tscn -- noche=5 escena=jefe duracion=12 arma=escopeta
```

Opciones (después de `--`):

| Opción | Qué hace | Ejemplo |
|---|---|---|
| `noche` | Noche a grabar (1–20, 21+ son Eternas) | `noche=20` |
| `escena` | `jefe` pone al jefe de esa noche enfrente; `horda` llena la arena de zombies | `escena=horda` |
| `fase` | Con `noche=20`, `fase=3` salta a la fase del escudo y los nodos | `fase=3` |
| `duracion` | Segundos de grabación | `duracion=12` |
| `arma` | Arma del jugador demo (id de `data/armas.json`) | `arma=smg` |
| `vida`, `nivel` | Vida máxima y nivel que muestra el HUD | `vida=400 nivel=11` |
| `vallas` | Cuántas vallas construir en círculo | `vallas=8` |
| `previos` | Zombies extra al empezar (modo horda) | `previos=18` |
| `radio`, `giro` | Radio y velocidad de las vueltas del jugador demo | `radio=5 giro=0.45` |

3. Borra `tools_tmp/` al terminar.

## Pasar a vertical (Reels / TikTok, 1080×1920)

```
ffmpeg -ss 1.3 -i clip.avi -t 11.5 -vf "crop=864:648:144:0,scale=1080:810:flags=neighbor,pad=1080:1920:0:560:color=0x0d0f16,drawtext=fontfile=RussoOne.ttf:text='TITULO':fontcolor=0xf97316:fontsize=64:x=(w-text_w)/2:y=230" -c:v libx264 -crf 23 -pix_fmt yuv420p reel.mp4
```

En `drawtext` no uses dos puntos (`:`) dentro del texto: ffmpeg los toma como separador.
`RussoOne.ttf` es la fuente del juego (licencia OFL, se puede redistribuir).
