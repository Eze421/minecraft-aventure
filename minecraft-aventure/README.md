# Base NFC para Godot

Proyecto mínimo para construir gameplay desde cero sobre una única entrada NFC.

## Flujo

```text
Arduino / app Android → HTTP GET /nfc?reader=2&d=<JSON> → NfcHttp → NfcRequirement
```

`NfcHttp` es un autoload: inicia el servidor HTTP en el puerto `8080`, valida
que cada lectura tenga `reader` mayor que cero y JSON con `v: 1` e `id`, y emite:

```gdscript
NfcHttp.item_received(item_id, reader_id, item)
```

El formato recibido es:

```json
{"v":1,"id":"CARD_001","name":"Madera","type":"wood"}
```

## Componente de requisito

Instanciá un `Node` en cualquier objeto de gameplay y adjuntale
la escena [`scenes/components/nfc_requirement.tscn`](scenes/components/nfc_requirement.tscn).
Su nodo raíz se llama **NfcRequirement**. En el Inspector configurá:

- `Requisito NFC > Ítem requerido`: lista desplegable generada desde
  `data/items.json` (`CARD_001`, `CARD_002`, etc.).
- `Requisito NFC > Lector requerido`: lista desplegable con **Cualquier
  lector** o **Lector 1** a **Lector 9**.
- `one_shot`: desactiva el requisito después de acertar.

El componente tiene una función que devuelve el resultado:

```gdscript
if $NfcRequirement.accepts("CARD_001", 2):
	print("true")
```

Y señales para usar en dinámica real:

```gdscript
$NfcRequirement.completed.connect(func(item, reader_id):
	# abrir puerta, fabricar objeto, avanzar misión, etc.
	pass
)
```

El juego recibe cada lectura por HTTP independientemente de que haya o no un
requisito activo. Cada objeto decide qué ID y qué lector acepta.

## Prueba incluida

La escena inicial es `scenes/nfc_requirement_test.tscn`. Tiene un `Area2D` con
un hijo **NfcRequirement** configurado para `CARD_001` en el lector `1`.
Mové el jugador azul con las flechas: al entrar se activa y al salir se
desactiva. Una lectura HTTP correcta actualiza el estado de la prueba.
