#!/usr/bin/env python3
"""Servicio continuo: reenvía el protocolo serial del RC522 a Godot.

Ejemplo:
  python3 serial_nfc_bridge.py --port /dev/ttyACM0

Mantiene el puerto abierto y se reconecta si se desconecta el Arduino.
"""

import argparse
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


def forward_event(endpoint: str, reader: str, uid: str) -> None:
    """Envía una lectura sin bloquear el bucle que escucha el Arduino."""
    query = urllib.parse.urlencode({"reader": reader, "uid": uid})
    try:
        with urllib.request.urlopen(f"{endpoint}?{query}", timeout=3) as response:
            print(f"UID {uid} -> Godot ({response.status})")
    except OSError as error:
        print(f"No se pudo enviar {uid} a Godot: {error}", file=sys.stderr)


def listen_forever(port: str, baud: int, endpoint: str, reconnect_delay: float) -> None:
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
                        sender.submit(forward_event, endpoint, reader, uid.upper())
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
    parser.add_argument("--reconnect-delay", type=float, default=2.0)
    args = parser.parse_args()
    if args.reconnect_delay <= 0:
        parser.error("--reconnect-delay debe ser mayor que cero.")
    listen_forever(args.port, args.baud, args.endpoint, args.reconnect_delay)


if __name__ == "__main__":
    main()
