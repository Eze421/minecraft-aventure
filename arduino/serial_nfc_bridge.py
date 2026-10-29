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
DEFAULT_MAP_FILE = Path(__file__).resolve().parent / "uid_card_map.json"
DEFAULT_ITEMS_FILE = Path(__file__).resolve().parent.parent / "minecraft-aventure" / "data" / "items.json"


def load_catalog(map_file: str, items_file: str) -> tuple[dict[str, str | None], dict[str, dict[str, str]]]:
    """Carga UID -> ID y el catálogo de ítems. Un UID pendiente usa null."""
    with open(map_file, encoding="utf-8") as file:
        uid_map = json.load(file)
    with open(items_file, encoding="utf-8") as file:
        items = json.load(file)
    if not isinstance(uid_map, dict) or not isinstance(items, dict):
        raise ValueError("Los dos archivos deben ser objetos JSON.")
    normalized_map: dict[str, str | None] = {}
    for uid, item_id in uid_map.items():
        uid = str(uid).upper()
        if item_id is None:
            normalized_map[uid] = None
            continue
        item_id = str(item_id)
        item = items.get(item_id)
        if not isinstance(item, dict) or not {"name", "type"}.issubset(item):
            raise ValueError(f"Ítem inválido para UID {uid}: {item_id}")
        normalized_map[uid] = item_id
    return normalized_map, items


def save_uid_map(map_file: str, uid_map: dict[str, str | None]) -> None:
    """Guarda los UID nuevos de forma legible, sin inventar qué ítem son."""
    Path(map_file).write_text(json.dumps(uid_map, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def register_pending_uid(map_file: str, uid_map: dict[str, str | None], uid: str) -> None:
    if uid in uid_map:
        return
    uid_map[uid] = None
    save_uid_map(map_file, uid_map)
    print(
        f"UID nuevo {uid} agregado como pendiente en {map_file}. "
        "Asignale un CARD_XXX y reiniciá el puente.",
        file=sys.stderr,
    )


def forward_event(
    endpoint: str,
    reader: str,
    uid: str,
    uid_map: dict[str, str | None],
    items: dict[str, dict[str, str]],
) -> None:
    """Convierte un UID de MIFARE Classic al mismo JSON NDEF que usa Android."""
    item_id = uid_map.get(uid)
    if item_id is None:
        print(f"UID pendiente sin ítem: {uid}", file=sys.stderr)
        return
    item = items[item_id]
    payload = json.dumps({"v": 1, "id": item_id, "name": item["name"], "type": item["type"]},
                         ensure_ascii=False, separators=(",", ":"))
    query = urllib.parse.urlencode({"reader": reader, "d": payload})
    try:
        with urllib.request.urlopen(f"{endpoint}?{query}", timeout=3) as response:
            print(f"UID {uid} -> {item_id} -> Godot ({response.status})")
    except OSError as error:
        print(f"No se pudo enviar UID {uid} a Godot: {error}", file=sys.stderr)


def listen_forever(
    port: str,
    baud: int,
    endpoint: str,
    reconnect_delay: float,
    uid_map: dict[str, str | None],
    items: dict[str, dict[str, str]],
    map_file: str,
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
                        uid = uid.upper()
                        register_pending_uid(map_file, uid_map, uid)
                        sender.submit(forward_event, endpoint, reader, uid, uid_map, items)
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
    parser.add_argument("--map-file", default=str(DEFAULT_MAP_FILE), help="Mapa UID -> ID.")
    parser.add_argument("--items-file", default=str(DEFAULT_ITEMS_FILE), help="Catálogo ID -> datos.")
    parser.add_argument("--reconnect-delay", type=float, default=2.0)
    args = parser.parse_args()
    if args.reconnect_delay <= 0:
        parser.error("--reconnect-delay debe ser mayor que cero.")
    try:
        uid_map, items = load_catalog(args.map_file, args.items_file)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        parser.error(f"No se pudo cargar el mapa local: {error}")
    assigned = sum(item_id is not None for item_id in uid_map.values())
    pending = len(uid_map) - assigned
    print(f"Puente UID activo: {assigned} asignada(s), {pending} pendiente(s).")
    listen_forever(args.port, args.baud, args.endpoint, args.reconnect_delay, uid_map, items, args.map_file)


if __name__ == "__main__":
    main()
