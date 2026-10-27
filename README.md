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
Usa un Arduino Mega 2560 con RC522 y emite eventos `READER=1;UID=...` a 115200
baudios. Para reenviar esos eventos por USB al receptor local de Godot, usar
[`arduino/serial_nfc_bridge.py`](arduino/serial_nfc_bridge.py).

Las guías detalladas están en
[`minecraft-aventure/README.md`](minecraft-aventure/README.md) y
[`android_nfc_bridge/README.md`](android_nfc_bridge/README.md).
