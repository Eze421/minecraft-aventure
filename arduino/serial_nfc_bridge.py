#!/usr/bin/env python3
"""Reenvía el protocolo serial del RC522 al receptor HTTP de Godot.

Ejemplo:
  python3 serial_nfc_bridge.py --port /dev/ttyACM0
"""

import argparse
import re
import sys
import urllib.parse
import urllib.request

try:
    import serial
except ImportError:
    sys.exit("Falta pyserial. Instalalo con: python3 -m pip install pyserial")


MESSAGE = re.compile(r"^READER=(\d+);UID=([0-9A-Fa-f]+)$")


def main() -> None:
    parser = argparse.ArgumentParser(description="Puente serial RC522 a Godot")
    parser.add_argument("--port", required=True, help="Ej.: /dev/ttyACM0 o COM3")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--endpoint", default="http://127.0.0.1:8080/nfc")
    args = parser.parse_args()

    with serial.Serial(args.port, args.baud, timeout=1) as device:
        print(f"Escuchando {args.port} y enviando a {args.endpoint}")
        for raw_line in device:
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
            query = urllib.parse.urlencode({"reader": reader, "uid": uid.upper()})
            try:
                with urllib.request.urlopen(f"{args.endpoint}?{query}", timeout=3) as response:
                    print(f"UID {uid.upper()} -> Godot ({response.status})")
            except OSError as error:
                print(f"No se pudo enviar {uid.upper()} a Godot: {error}", file=sys.stderr)


if __name__ == "__main__":
    main()
