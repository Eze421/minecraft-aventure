# Puentes Arduino NFC

Hay dos rutas separadas. Ambas envían a Godot el mismo parámetro HTTP
`d={"v":1,"id":"..."}`, por lo que no cambia el gameplay.

## MIFARE Classic actual: UID local

Usá `codigo_lectura/codigo_lectura.ino` con las tarjetas del kit y ejecutá:

```bash
python3 serial_nfc_bridge.py --port /dev/ttyACM0
```

El firmware emite `READER=n;UID=...`. El puente busca el UID en
`uid_card_map.json`, busca el ítem en `../minecraft-aventure/data/items.json`
y genera el JSON NDEF para Godot. Agregá un UID nuevo al mapa indicando su ID:

```json
"UID_DE_LA_TARJETA": "CARD_001"
```

Si el puente lee un UID que no existe, lo agrega automáticamente con valor
`null` y **no lo envía al juego**. Solo hay que reemplazar ese `null` por el
ID elegido, por ejemplo `"CARD_004"`, y reiniciar el puente. Esto evita que
una tarjeta nueva quede asociada accidentalmente al ítem incorrecto.

## Futuro: NTAG213/215 con NDEF físico

Cuando se usen tarjetas NTAG213/215 regrabables, cargá
`codigo_lectura_ntag/codigo_lectura_ntag.ino` y ejecutá:

```bash
python3 serial_ndef_bridge.py --port /dev/ttyACM0
```

Esta ruta lee el texto NDEF físico y lo reenvía sin consultar mapas de UID.
La tarjeta debe contener un registro de texto como:

```json
{"v":1,"id":"CARD_001","name":"Madera","type":"wood"}
```

`diagnostico_mifare_classic/` es un sketch independiente de solo lectura para
inspeccionar las MIFARE Classic actuales. No lo ejecutes junto al puente del
juego.
