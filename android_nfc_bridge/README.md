# Puente NFC para Android

Esta mini app lee un registro NDEF de texto de una tarjeta y lo envía al
receptor HTTP de Godot. Las tarjetas no guardan ninguna IP ni URL.

## Preparación

1. Abrí la carpeta `android_nfc_bridge` con Android Studio.
2. Aceptá instalar el SDK que solicite Android Studio y sincronizá Gradle.
3. Conectá el Poco por USB con depuración USB activada, o usá la instalación
   inalámbrica de Android Studio.
4. Ejecutá la configuración `app` en el teléfono.

## Uso

1. Ejecutá el juego Godot y anotá su dirección Wi-Fi, por ejemplo
   `http://192.168.100.48:8080/nfc`.
2. Abrí la app **Puente NFC → Godot**, escribí esa dirección y tocá
   **Guardar dirección**.
3. Tocá **Leer tarjeta** y recién entonces acercá una tarjeta. La app mostrará
   el JSON leído y la respuesta de Godot, para que sea fácil detectar si el
   problema está en la tarjeta, la red o el juego.
4. Para una mesa de juego, usá **Iniciar lectura continua**. Cada tarjeta se
   envía una vez y la app evita reenviar repetidamente la misma mientras queda
   apoyada sobre el teléfono.

## Catálogo actual

La lista de grabado rápido de la app, `data/cards.json` y el puzzle de Godot
usan exactamente estos datos. El orden válido es Madera → Piedra → Hierro.

| Ítem | ID | Nombre | Tipo |
| --- | --- | --- | --- |
| Madera | `CARD_001` | `Madera` | `wood` |
| Piedra | `CARD_002` | `Piedra` | `stone` |
| Hierro | `CARD_003` | `Hierro` | `iron` |

Si preferís escribirlas con NFC Tools, usá `Write > Add a record > Custom text`
y uno de estos contenidos:

```json
{"v":1,"id":"CARD_001","name":"Madera","type":"wood"}
```

```json
{"v":1,"id":"CARD_002","name":"Piedra","type":"stone"}
```

```json
{"v":1,"id":"CARD_003","name":"Hierro","type":"iron"}
```

Al acercar una tarjeta, la app mostrará la respuesta de Godot. El juego acepta
el orden Madera → Piedra → Hierro.

La app usa el lector NFC mientras está en primer plano y después de tocar
**Leer tarjeta**. Esto evita registrar URLs por tarjeta y permite cambiar de
red cambiando una única dirección en la app.

## Grabado rápido

También podés grabar tarjetas sin NFC Tools: elegí el ítem en la lista. La app
completa **ID interno**, **Nombre** y **Tipo** automáticamente. Luego tocá
**Grabar tarjeta con estos datos** y acercá una tarjeta NDEF regrabable. Si la
tarjeta está virgen, la app intenta formatearla como NDEF antes de escribirla.
Los campos siguen siendo editables si necesitás crear una tarjeta especial.

```json
{"v":1,"id":"CARD_001","name":"Madera","type":"wood"}
```

No bloquees las tarjetas durante las pruebas, para poder actualizarlas después.

### Compatibilidad y tarjetas protegidas

La app escribe cualquier tarjeta que el teléfono exponga como **NDEF writable**
o que Android permita formatear a NDEF. Esto incluye normalmente las
MIFARE Ultralight/NTAG regrabables y las MIFARE Classic que ya estén
formateadas para NDEF y cuyas claves autoricen la escritura.

Una MIFARE Classic 1K con sectores protegidos no puede reprogramarse sin las
claves de esos sectores. Encontrar la clave `FF FF FF FF FF FF` solamente en
el sector 0 no alcanza: el bloque 0 contiene datos del fabricante y los datos
NDEF requieren sectores de datos autorizados. La app no intenta eludir ni
adivinar claves. Para esas tarjetas, usá las claves proporcionadas por su
propietario o reemplazalas por tarjetas NDEF regrabables nuevas.
