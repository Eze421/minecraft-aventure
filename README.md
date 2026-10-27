# Minecraft Game

Monorepo de la experiencia NFC 2D.

| Carpeta | Contenido |
| --- | --- |
| `minecraft-aventure/` | Juego, escenas y documentación de Godot. |
| `android_nfc_bridge/` | Aplicación Android para leer/grabar NDEF y transmitirlos a Godot. |
| `arduino/` | Firmware RC522 y puente USB/Serial hacia Godot. |

## Arduino

El firmware histórico está recuperado en
[`arduino/codigo_lectura/codigo_lectura.ino`](arduino/codigo_lectura/codigo_lectura.ino).
Usa un Arduino Mega 2560 con hasta nueve RC522 y emite eventos
`READER=1;UID=...` hasta `READER=9;UID=...` a 115200 baudios. Todos comparten
SPI del Mega (`SCK=52`, `MOSI=51`, `MISO=50`). El firmware deja preparados
`SDA/RST`: L1 `53/5`, L2 `49/6`, L3 `47/7`, L4 `45/8`, L5 `43/9`, L6 `41/10`,
L7 `39/11`, L8 `37/12`, L9 `35/13`. Para activar más lectores se incrementa
`ACTIVE_READER_COUNT` en el sketch. Para reenviar esos eventos por USB al receptor local de Godot, usar
[`arduino/serial_nfc_bridge.py`](arduino/serial_nfc_bridge.py).

El puente se ejecuta una sola vez y queda escuchando el puerto continuamente.
También se reconecta automáticamente si el Arduino se desconecta y vuelve a
conectarse. Antes de enviar una lectura, busca el UID en
`minecraft-aventure/data/cards.json` y transmite el mismo JSON NDEF (`d=...`)
que utiliza la app Android. Así ambos lectores entregan exactamente el mismo
tipo de evento al juego.

Las guías detalladas están en
[`minecraft-aventure/README.md`](minecraft-aventure/README.md) y
[`android_nfc_bridge/README.md`](android_nfc_bridge/README.md).
