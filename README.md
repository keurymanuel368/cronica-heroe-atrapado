# Crónica del Héroe Atrapado

RPG de acción en 3D, estilo anime, hecho con **Godot 4.3**. Despiertas atrapado dentro de un mundo que funciona como un videojuego y la única salida es subir de nivel.

## Estado

**Fase 1 · Prototipo** — el héroe camina, corre y salta por un prado con bosque, rocas y plataformas de piedra, con cámara en tercera persona y estilo cel-shading.

Fases del proyecto: 1 Prototipo · 2 Combate · 3 Mundo · 4 Gremios y misiones · 5 Historia · 6 Pulido.

## Cómo jugar

1. Descarga [CronicaDelHeroeAtrapado.zip](https://github.com/keurymanuel368/cronica-heroe-atrapado/raw/descargas/CronicaDelHeroeAtrapado.zip) (Windows, 64 bits).
2. Clic derecho en el .zip → **Extraer todo**, y abre el .exe con doble clic.

Solo se descarga una vez. Cada vez que abres el juego, la pantalla de inicio busca la versión más nueva en la rama `descargas` y se actualiza sola (si no hay internet, juega con la última versión guardada).

| Tecla | Acción |
| --- | --- |
| W A S D | Moverse |
| Shift | Correr |
| Espacio | Saltar |
| Ratón | Girar la cámara (clic en la ventana para empezar) |
| Rueda | Acercar o alejar la cámara |
| G | Celebrar |
| F11 | Pantalla completa |
| Esc | Soltar el ratón |
| H | Mostrar u ocultar la ayuda |

También funciona con mando (stick izquierdo para moverse, derecho para la cámara, A para saltar).

## Abrir el proyecto

1. Instala [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/).
2. Abre Godot, pulsa **Importar** y elige `project.godot`.
3. Pulsa F5 para jugar.

## Estructura

- `scenes/main.tscn` — escena principal.
- `scripts/boot.gd` — pantalla de inicio que descarga las actualizaciones.
- `scripts/main.gd` — construye el mundo, la luz, el cielo y la interfaz.
- `scripts/player.gd` — movimiento del héroe, animaciones y cámara.
- `scripts/toon.gd` — estilo anime (sombras en bandas y contorno).
- `shaders/grass.gdshader` — pasto y camino de tierra.
- `assets/kaykit/` — modelos 3D.

## Publicar una actualización

`tools/publicar.sh` sube el número de versión, exporta el juego y lo deja en la rama `descargas`. Con `--exe` también genera el .exe y su .zip.

## Créditos

Modelos 3D de **KayKit** por Kay Lousberg ([kaylousberg.com](https://www.kaylousberg.com)), licencia CC0:
Adventurers Character Pack y Medieval Hexagon Pack.

Héroe: modelo de muestra **HairSample_Male** de VRoid (licencia CC0), con animaciones de KayKit trasladadas a su esqueleto.
