# Minecraft Aventure — prototipo NFC 2D

Experiencia 2D corta para exposición, inspirada en Minecraft. Las tarjetas NFC
representan materiales y activan la lógica del juego en Godot.

El proyecto está diseñado para que la lógica no dependa del origen de la
lectura: durante el desarrollo se puede usar el simulador de teclado o la app
Android; en la instalación final, Arduino y lectores NFC enviarán el mismo
evento interno.

## Estado actual

- Escena 2D funcional con un puzzle de tres pasos.
- Simulador de teclado: `1` Madera, `2` Piedra, `3` Hierro y `R` reinicia.
- Control de orden de tarjetas y bloqueo de lecturas repetidas.
- Base de datos de tarjetas con UID como compatibilidad para hardware futuro.
- Receptor HTTP local para las lecturas de la app Android.
- App Android compañera para leer, grabar y enviar tarjetas NDEF por Wi-Fi.

El orden actual del puzzle es **Madera → Piedra → Hierro**.

## Arquitectura

```text
Tarjeta NDEF de texto
        │
        ▼
App Android Puente NFC → Godot
        │  Wi-Fi / HTTP local
        ▼
Godot: HttpNfcReceiver
        │
        ▼
NfcEventSource → GameController → interfaz 2D
```

La futura ruta física mantiene la misma capa de juego:

```text
Tarjeta NFC → lector → Arduino → USB/Serial → NfcEventSource → GameController
```

## Requisitos

### Juego

- Godot 4.x.

### Pruebas NFC por teléfono

- Teléfono Android con NFC (probado con tarjetas NFC-A/NDEF como NTAG213 y
  NTAG215).
- PC y teléfono conectados a la misma red Wi-Fi.
- Android Studio para instalar la app compañera.

## Ejecutar el juego

1. Abrí este directorio con Godot 4.
2. Ejecutá el proyecto (`F6` o el botón Play).
3. Probá el puzzle con `1`, `2`, `3` y `R`.
4. Para usar NFC real, mantené Godot abierto: mostrará la dirección local del
   receptor, por ejemplo `http://192.168.100.48:8080/nfc`.

Si el sistema pregunta por el firewall, permití conexiones privadas para
Godot. No expongas el puerto `8080` a Internet.

## App Android: Puente NFC → Godot

La app está en [`android_nfc_bridge`](android_nfc_bridge). Lee un registro NDEF
de texto y lo transmite a Godot; por eso las tarjetas no guardan la IP de la
PC ni URLs.

1. Abrí `android_nfc_bridge` en Android Studio.
2. Ejecutá la configuración `app` en el teléfono.
3. Copiá en la app la dirección que muestra Godot y guardala.
4. Usá **Lectura continua** para enviar tarjetas al juego.
5. Usá **Grabado rápido** para seleccionar y escribir una tarjeta sin abrir
   NFC Tools.

La guía detallada está en [`android_nfc_bridge/README.md`](android_nfc_bridge/README.md).

## Catálogo de tarjetas

Este catálogo es consistente entre Godot, la app Android y la documentación.

| Ítem | ID | Nombre | Tipo |
| --- | --- | --- | --- |
| Madera | `CARD_001` | `Madera` | `wood` |
| Piedra | `CARD_002` | `Piedra` | `stone` |
| Hierro | `CARD_003` | `Hierro` | `iron` |

El JSON NDEF almacenado en cada tarjeta usa este formato:

```json
{"v":1,"id":"CARD_001","name":"Madera","type":"wood"}
```

`id` es la identidad estable de juego. El UID físico no es la identidad de la
tarjeta: puede cambiarse un chip sin modificar la lógica, escribiendo los mismos
datos NDEF en el reemplazo.

## Pedir una tarjeta desde el gameplay

El receptor NFC queda activo permanentemente en segundo plano. Una lectura no
modifica el juego por sí sola: el gameplay debe pedir explícitamente el objeto
que espera mediante `GameController.request_nfc(valor)`.

```gdscript
# Las tres llamadas son equivalentes con el catálogo actual.
game.request_nfc("wood")
game.request_nfc("Madera")
game.request_nfc("CARD_001")
```

La función busca `tipo`, `nombre` o `ID` en el catálogo y devuelve `true` si
existe. Solo la tarjeta solicitada completa la espera. Las lecturas ocurridas
sin una solicitud activa se ignoran; las tarjetas equivocadas no avanzan el
juego. Al aceptar una lectura se emite `nfc_request_completed(card, reader_id)`.

## Escena aislada de prueba NFC

Abrí y ejecutá `scenes/nfc_test.tscn` para comprobar la arquitectura sin tocar
la escena principal. La escena contiene dos capas:

- `NfcBackground`: inicia el servidor HTTP, escucha constantemente y muestra
  por `print()` cada UID o JSON NDEF que recibe en el panel **Output**.
- `GameplayLayer`: contiene un jugador azul y un bloque dorado. Al entrar en
  el `Area2D` del bloque, el gameplay llama `request_item("wood")`.

Mové el jugador con las flechas. Una vez activada la zona, escaneá Madera con
la app Android o presioná `1` para simularla. Una tarjeta leída antes de entrar
en el área queda solo registrada en Output y no modifica el gameplay.

## Estructura

```text
scenes/                 Escenas de Godot
scripts/                Lógica de juego, NFC y receptor HTTP
data/cards.json         Mapeo de UID legado a tarjeta interna
android_nfc_bridge/     Aplicación Android lectora/grabadora NDEF
documents/readme.me     Documentación técnica extendida
```

## Próximos pasos

1. Definir el diseño final del puzzle y sus estados.
2. Probar lectura continua prolongada con las tarjetas físicas.
3. Integrar Arduino y uno o más lectores NFC.
4. Conectar el adaptador serie a `NfcEventSource.parse_serial_message()`.
5. Preparar recuperación ante desconexión y pruebas de exposición.

## Notas de desarrollo

- La app Android debe permanecer en primer plano para el modo lector.
- No bloquees tarjetas NFC durante las pruebas, así pueden reescribirse.
- La documentación técnica detallada está en `documents/readme.me`.
