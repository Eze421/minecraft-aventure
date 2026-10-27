#!/usr/bin/env python3
"""Servicio continuo: reenvía el protocolo serial del RC522 a Godot.

Ejemplo:
  python3 serial_nfc_bridge.py --port /dev/ttyACM0

Mantiene el puerto abierto y se reconecta si se desconecta el Arduino.
"""

import argparse
import json
from pathlib import Path
import re
import sys
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

try:
    import serial
except ImportError:
    sys.exit("Falta pyserial. Instalalo con: python3 -m pip install pyserial")


MESSAGE = re.compile(r"^READER=(\d+);UID=([0-9A-Fa-f]+)$")
DEFAULT_CARDS_FILE = Path(__file__).resolve().parent.parent / "minecraft-aventure" / "data" / "cards.json"
DEFAULT_ITEMS_FILE = Path(__file__).resolve().parent.parent / "minecraft-aventure" / "data" / "items.json"


def load_cards(cards_file: str, items_file: str) -> dict[str, dict[str, str]]:
    """Une UID -> ID e ID -> datos, igual que la base de Godot."""
    with open(cards_file, encoding="utf-8") as file:
        uid_to_item = json.load(file)
    with open(items_file, encoding="utf-8") as file:
        items_by_id = json.load(file)
    if not isinstance(uid_to_item, dict):
        raise ValueError("cards.json debe ser un objeto JSON UID -> ID de ítem.")
    if not isinstance(items_by_id, dict):
        raise ValueError("items.json debe ser un objeto JSON ID -> datos de ítem.")

    cards: dict[str, dict[str, str]] = {}
    for uid, item_id in uid_to_item.items():
        item_id = str(item_id)
        item = items_by_id.get(item_id)
        if not isinstance(item, dict) or not all(key in item for key in ("name", "type")):
            raise ValueError(f"Ítem inválido o ausente para UID {uid}: {item_id}.")
        cards[str(uid).upper()] = {"id": item_id, **item}
    return cards


def ndef_payload(card: dict[str, str]) -> str:
    """Genera exactamente el formato NDEF JSON que envía la app Android."""
    return json.dumps(
        {"v": 1, "id": card["id"], "name": card["name"], "type": card["type"]},
        ensure_ascii=False,
        separators=(",", ":"),
    )


def forward_event(endpoint: str, reader: str, uid: str, cards: dict[str, dict[str, str]]) -> None:
    """Reenvía el mismo parámetro d=<JSON NDEF> que usa Android."""
    card = cards.get(uid)
    if card is None:
        print(f"UID desconocido {uid}: no se envía a Godot.", file=sys.stderr)
        return
    payload = ndef_payload(card)
    query = urllib.parse.urlencode({"reader": reader, "d": payload})
    try:
        with urllib.request.urlopen(f"{endpoint}?{query}", timeout=3) as response:
            print(f"UID {uid} ({card['name']}) -> Godot ({response.status})")
    except OSError as error:
        print(f"No se pudo enviar {uid} a Godot: {error}", file=sys.stderr)


def listen_forever(
    port: str,
    baud: int,
    endpoint: str,
    reconnect_delay: float,
    cards: dict[str, dict[str, str]],
) -> None:
    """Escucha el puerto de forma permanente y recupera desconexiones USB."""
    with ThreadPoolExecutor(max_workers=1, thread_name_prefix="godot-http") as sender:
        while True:
            try:
                with serial.Serial(port, baud, timeout=1) as device:
                    print(f"Arduino conectado en {port} a {baud} baudios.")
                    print(f"Escuchando continuamente y enviando a {endpoint}")
                    while True:
                        raw_line = device.readline()
                        if not raw_line:
                            continue
                        line = raw_line.decode("ascii", errors="replace").strip()
                        if line in {"READY", "READER_CONNECTED"}:
                            print(f"Arduino: {line}")
                            continue
                        match = MESSAGE.fullmatch(line)
                        if not match:
                            if line:
                                print(f"Mensaje ignorado: {line}", file=sys.stderr)
                            continue
                        reader, uid = match.groups()
                        sender.submit(forward_event, endpoint, reader, uid.upper(), cards)
            except serial.SerialException as error:
                print(
                    f"Arduino no disponible en {port}: {error}. "
                    f"Reintentando en {reconnect_delay:g} s...",
                    file=sys.stderr,
                )
                time.sleep(reconnect_delay)


def main() -> None:
    parser = argparse.ArgumentParser(description="Puente serial RC522 a Godot")
    parser.add_argument("--port", required=True, help="Ej.: /dev/ttyACM0 o COM3")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--endpoint", default="http://127.0.0.1:8080/nfc")
    parser.add_argument(
        "--cards-file",
        default=str(DEFAULT_CARDS_FILE),
        help="Ruta a cards.json (UID -> ID) de Godot.",
    )
    parser.add_argument(
        "--items-file",
        default=str(DEFAULT_ITEMS_FILE),
        help="Ruta a items.json (ID -> datos) de Godot.",
    )
    parser.add_argument("--reconnect-delay", type=float, default=2.0)
    args = parser.parse_args()
    if args.reconnect_delay <= 0:
        parser.error("--reconnect-delay debe ser mayor que cero.")
    try:
        cards = load_cards(args.cards_file, args.items_file)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        parser.error(f"No se pudo cargar el catálogo: {error}")
    print(f"Catálogo cargado: {len(cards)} UID(s) desde {args.cards_file} + {args.items_file}")
    listen_forever(args.port, args.baud, args.endpoint, args.reconnect_delay, cards)


if __name__ == "__main__":
    main()
