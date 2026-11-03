# Manual del sistema de cámaras cinemáticas

Este proyecto usa una única `CinematicCamera` dentro de `Player`. La escena principal, mediante el script `TestScene`, es quien decide cuándo se muestra cada plano. Los nodos `CinematicShot` no son cámaras: son marcas de posición y objetivo que la cámara usa como destino.

## Estructura necesaria

En la escena principal debe existir una estructura similar a esta:

```text
Escena principal (script: TestScene)
├── Player
│   └── Camera3D (script: CinematicCamera)
├── CinematicShots
│   ├── Overview (CinematicShot)
│   └── NfcCloseup (CinematicShot)
└── Area3D
```

El nombre del contenedor puede ser cualquiera, por ejemplo `CinematicShots2`. En el nodo raíz que tiene `TestScene`, configurá en el Inspector **Cámara y encuadres > Shots Container Path** con ese nodo.

`TestScene` busca los planos únicamente dentro de ese contenedor. Así cada escena controla sus propios planos y no se mezclan con los de otra escena.

## Crear un plano

1. Dentro del contenedor de planos, agregá un `Marker3D`.
2. Asignale el script `res://scripts/player/cinematic_shot.gd`, o instanciá la plantilla `res://scenes/components/cinematic_shot.tscn`.
3. Renombralo con un nombre único, por ejemplo `PuertaCloseup`.
4. Movelo y rotalo en el editor hasta conseguir el encuadre deseado. La posición es la ubicación de la cámara.
5. En el Inspector del plano, configurá **Look Target Path** con el `Node3D` que la cámara debe mirar.
6. Opcionalmente asigná una plantilla en **Template**. Las plantillas disponibles son:
   - `cinematic_shot_wide.tres`: plano abierto.
   - `cinematic_shot_close_up.tres`: primer plano.
   - `cinematic_shot_object_focus.tres`: foco de objeto.

La plantilla define duración de transición, campo de visión (`FOV`) y desplazamiento del punto de mirada. Si no asignás una, el plano usa sus valores propios.

## Cambiar de plano desde código

Usá siempre el controlador de la escena, no la cámara directamente:

```gdscript
TestScene.current.switch_to_shot("PuertaCloseup")
TestScene.current.return_to_player()
```

También están disponibles estos atajos para los planos ya incluidos:

```gdscript
TestScene.current.switch_to_overview()
TestScene.current.switch_to_nfc_closeup()
TestScene.current.toggle_shot("Overview")
```

Para cambiar la duración solo en esa llamada:

```gdscript
TestScene.current.switch_to_shot("PuertaCloseup", 1.5)
```

La duración enviada en la llamada tiene prioridad sobre la de la plantilla.

## Conectar un `Area3D`

Un `Area3D` requiere un `CollisionShape3D` con una forma asignada. Para detectar al jugador, verificá que el `collision_mask` del área incluya la capa donde está el `CharacterBody3D` del jugador.

### Opción 1: conexión automática de la escena de prueba

La escena actual tiene un `Area3D` directo bajo la raíz. `TestScene` lo detecta por ese nombre y conecta sus señales automáticamente:

```text
Area3D.body_entered -> switch_to_nfc_closeup()
Area3D.body_exited  -> return_to_player()
```

Esta opción sirve para el altar NFC de prueba. Para usarla, mantené el nombre `Area3D` y los planos `NfcCloseup` y `Overview` según corresponda.

### Opción 2: script específico en el área

Es la opción recomendada para objetos distintos. Asigná este script a un `Area3D` y cambiá el nombre del plano exportado desde el Inspector:

```gdscript
extends Area3D

@export var shot_name := "PuertaCloseup"
@export var return_on_exit := true

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		TestScene.current.switch_to_shot(shot_name)

func _on_body_exited(body: Node3D) -> void:
	if return_on_exit and body.is_in_group("player"):
		TestScene.current.return_to_player()
```

Conectá en el editor las señales `body_entered` y `body_exited` del `Area3D` a las dos funciones del script.

### Opción 3: conectar la señal desde otro script

Útil si un administrador de misión, diálogo o NFC decide cuándo se cambia la cámara:

```gdscript
func _on_altar_activado() -> void:
	TestScene.current.switch_to_shot("NfcCloseup", 0.6)

func _on_dialogo_terminado() -> void:
	TestScene.current.return_to_player()
```

No hace falta que el disparador sea un área: puede ser una interacción, una lectura NFC válida, un diálogo, una animación o una misión.

## Controles de prueba

En el Inspector del nodo raíz con `TestScene`, activá **Debug Keys Enabled**.

- `1`: vuelve al seguimiento del jugador.
- `2`: activa `Overview`.
- `3`: activa `NfcCloseup`.

La cámara no procesa estas teclas: las procesa la escena principal. Esto evita que dos sistemas intenten cambiar de plano a la vez.

En seguimiento de jugador, clic izquierdo captura el mouse y permite orbitar. La cámara se ajusta desde el Inspector de `Player/Camera3D` mediante `Follow Offset`, `Follow Focus Height`, `Follow Smoothing` y los parámetros de **Órbita con mouse**.

## Diagnóstico rápido

- Si aparece `No existe el shot`: revisá el nombre del `CinematicShot` y que esté dentro del nodo seleccionado en **Shots Container Path**.
- Si el área no reacciona: revisá que tenga `CollisionShape3D`, capas/máscaras compatibles y que el jugador pertenezca al grupo `player`.
- Si la cámara no aparece: comprobá que `Player/Camera3D` use `cinematic_camera.gd` y sea la cámara actual.
- Si el plano mira al lugar equivocado: corregí el `Look Target Path` del `CinematicShot` y, si hace falta, su `Look At Offset` o plantilla.
