#!/usr/bin/env python3
"""Puente futuro: reenvía NDEF físico de NTAG213/215 a Godot, sin usar UID."""
import argparse
import json
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

MESSAGE = re.compile(r"^READER=(\d+);NDEF=(.+)$")

def forward(endpoint: str, reader: str, payload: str) -> None:
    try:
        data = json.loads(payload)
        if not isinstance(data, dict) or not {"v", "id"}.issubset(data): raise ValueError("faltan v o id")
        query = urllib.parse.urlencode({"reader": reader, "d": payload})
        with urllib.request.urlopen(f"{endpoint}?{query}", timeout=3) as response:
            print(f"NDEF {data['id']} -> Godot ({response.status})")
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"No se pudo reenviar NDEF: {error}", file=sys.stderr)

def main() -> None:
    parser = argparse.ArgumentParser(description="Puente NDEF físico NTAG a Godot")
    parser.add_argument("--port", required=True)
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--endpoint", default="http://127.0.0.1:8080/nfc")
    args = parser.parse_args()
    with ThreadPoolExecutor(max_workers=1) as sender:
        while True:
            try:
                with serial.Serial(args.port, args.baud, timeout=1) as device:
                    print(f"Esperando NDEF físico en {args.port}.")
                    while True:
                        line = device.readline().decode("utf-8", errors="replace").strip()
                        match = MESSAGE.fullmatch(line)
                        if match: sender.submit(forward, args.endpoint, *match.groups())
            except serial.SerialException as error:
                print(f"Arduino no disponible: {error}. Reintentando...", file=sys.stderr)
                time.sleep(2)

if __name__ == "__main__": main()
