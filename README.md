# Crónica del Héroe Atrapado

RPG de acción en 3D, estilo anime, hecho con **Godot 4.3**. Despiertas atrapado dentro de un mundo que funciona como un videojuego y la única salida es subir de nivel.

## Estado

**Fase 1 · Prototipo** — el héroe camina, corre y salta por un prado con bosque, rocas y plataformas de piedra, con cámara en tercera persona y estilo cel-shading.

Fases del proyecto: 1 Prototipo · 2 Combate · 3 Mundo · 4 Gremios y misiones · 5 Historia · 6 Pulido.

## Cómo jugar

Abre `CronicaDelHeroeAtrapado.exe` (se entrega en cada fase) con doble clic en Windows de 64 bits. No hace falta instalar nada. Para generarlo tú mismo desde Godot: **Proyecto → Exportar → Windows Desktop**.

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
- `scripts/main.gd` — construye el mundo, la luz, el cielo y la interfaz.
- `scripts/player.gd` — movimiento del héroe, animaciones y cámara.
- `scripts/toon.gd` — estilo anime (sombras en bandas y contorno).
- `shaders/grass.gdshader` — pasto y camino de tierra.
- `assets/kaykit/` — modelos 3D.

## Créditos

Modelos 3D de **KayKit** por Kay Lousberg ([kaylousberg.com](https://www.kaylousberg.com)), licencia CC0:
Adventurers Character Pack y Medieval Hexagon Pack.
