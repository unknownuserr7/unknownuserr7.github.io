#!/usr/bin/env python3
"""
sensor_reader.py
────────────────────────────────────────────────────────────────
Lectura del sensor de temperatura DS18B20 via 1-Wire (Raspberry Pi)
i desament de les dades al fitxer data/temperatures.json

Autors: Cludi i Abel · SMX 2-A · 2025-26
────────────────────────────────────────────────────────────────
"""

import json
import os
import glob
import time
import logging
import argparse
from datetime import datetime
from pathlib import Path

# ── CONFIGURACIÓ ─────────────────────────────────────────────────────────────
DATA_FILE    = Path(__file__).parent.parent / "data" / "temperatures.json"
LOG_FILE     = Path(__file__).parent.parent / "data" / "sensor.log"
MAX_RECORDS  = 10000       # Nombre màxim de lectures al fitxer JSON
SIMULATE     = False       # Posar True per a proves sense sensor físic

# ── LOGGING ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
log = logging.getLogger(__name__)


# ── LECTURA DEL SENSOR (1-Wire via sysfs) ────────────────────────────────────
def find_sensor_device():
    """Localitza el fitxer del sensor DS18B20 al sistema d'arxius."""
    base = "/sys/bus/w1/devices/"
    devices = glob.glob(base + "28-*")   # DS18B20 sempre comença per 28-
    if not devices:
        return None
    return devices[0] + "/w1_slave"


def read_raw(device_file: str) -> str:
    """Llegeix el contingut raw del fitxer del sensor."""
    with open(device_file, "r") as f:
        return f.read()


def parse_temperature(raw: str) -> float | None:
    """
    Parseja la sortida del sensor. Exemple de sortida:
        50 05 4b 46 7f ff 0c 10 1c : crc=1c YES
        50 05 4b 46 7f ff 0c 10 1c t=21312
    Retorna la temperatura en graus Celsius o None si CRC falla.
    """
    lines = raw.strip().splitlines()
    if len(lines) < 2:
        return None
    if "YES" not in lines[0]:
        log.warning("CRC incorrecte. Sensor potser desconnectat o soroll al cable.")
        return None
    t_pos = lines[1].find("t=")
    if t_pos == -1:
        return None
    temp_raw = int(lines[1][t_pos + 2:])
    return round(temp_raw / 1000.0, 2)


def read_temperature_hw() -> float | None:
    """Lectura real del sensor DS18B20 via 1-Wire."""
    device = find_sensor_device()
    if device is None:
        log.error("Sensor DS18B20 no trobat. Comprova la connexió i que 1-Wire estigui activat.")
        return None
    try:
        raw = read_raw(device)
        temp = parse_temperature(raw)
        if temp is not None:
            log.info(f"Sensor detectat: {device.split('/')[5]} → {temp}°C")
        return temp
    except Exception as e:
        log.error(f"Error llegint el sensor: {e}")
        return None


def read_temperature_simulated() -> float:
    """Temperatura simulada amb variació sinusoïdal (per a proves sense sensor)."""
    import math
    h = datetime.now().hour + datetime.now().minute / 60
    base = 20.0
    daily_wave  = math.sin((h - 6) * math.pi / 12) * 3.5   # Cycle 24h
    noise       = (os.urandom(1)[0] / 255 - 0.5) * 0.6     # Soroll ±0.3°
    temp = round(base + daily_wave + noise, 2)
    log.info(f"[SIMULAT] Temperatura: {temp}°C")
    return temp


def read_temperature(simulate: bool = False) -> float | None:
    """Punt d'entrada per llegir temperatura (real o simulada)."""
    if simulate:
        return read_temperature_simulated()
    return read_temperature_hw()


# ── GESTIÓ DEL FITXER JSON ───────────────────────────────────────────────────
def load_existing_data() -> list:
    """Carrega el fitxer JSON existent o retorna llista buida."""
    DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
    if not DATA_FILE.exists():
        log.info(f"Fitxer nou: {DATA_FILE}")
        return []
    try:
        with open(DATA_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            if not isinstance(data, list):
                log.warning("Format inesperat al JSON, reiniciant...")
                return []
            return data
    except (json.JSONDecodeError, IOError) as e:
        log.error(f"Error llegint {DATA_FILE}: {e}")
        return []


def save_data(data: list):
    """Desa la llista de lectures al fitxer JSON."""
    # Limitar el nombre de registres per evitar que el fitxer creixi massa
    if len(data) > MAX_RECORDS:
        data = data[-MAX_RECORDS:]
        log.info(f"Neteja: conservant últims {MAX_RECORDS} registres.")
    tmp = DATA_FILE.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    tmp.replace(DATA_FILE)   # Escriptura atòmica (evita corrupció)
    log.info(f"Desat a {DATA_FILE} ({len(data)} registres totals)")


def add_reading(temperature: float):
    """Afegeix una nova lectura al fitxer JSON."""
    data = load_existing_data()
    entry = {
        "timestamp":   datetime.now().isoformat(),
        "temperature": temperature,
        "unit":        "celsius"
    }
    data.append(entry)
    save_data(data)
    return entry


# ── MAIN ──────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="Lectura del sensor DS18B20 i desament a JSON"
    )
    parser.add_argument(
        "--simulate", "-s", action="store_true",
        help="Usar temperatura simulada (sense sensor físic)"
    )
    parser.add_argument(
        "--continuous", "-c", type=int, default=0, metavar="INTERVAL",
        help="Lectura contínua cada N minuts (0 = lectura única)"
    )
    args = parser.parse_args()

    simulate = args.simulate or SIMULATE

    if simulate:
        log.warning("⚠️  Mode simulació activat. Dades NO provenen del sensor físic.")

    if args.continuous > 0:
        log.info(f"Mode contínu: lectura cada {args.continuous} minuts. Ctrl+C per aturar.")
        while True:
            temp = read_temperature(simulate)
            if temp is not None:
                add_reading(temp)
            time.sleep(args.continuous * 60)
    else:
        temp = read_temperature(simulate)
        if temp is None:
            log.error("No s'ha pogut obtenir la temperatura. Sortint.")
            raise SystemExit(1)
        entry = add_reading(temp)
        print(f"\n✓ Temperatura registrada: {entry['temperature']}°C ({entry['timestamp']})")


if __name__ == "__main__":
    main()
