#!/bin/bash
# ════════════════════════════════════════════════════════════════
# sync_github.sh
# Llegeix el sensor DS18B20, desa les dades i puja a GitHub
#
# Autors: Cludi i Abel · SMX 2-A · 2025-26
# ════════════════════════════════════════════════════════════════

set -e   # Sortir si hi ha algun error

# ── CONFIGURACIÓ ─────────────────────────────────────────────────
REPO_DIR="$HOME/sensor-data"          # Directori del repositori
PYTHON_SCRIPT="$REPO_DIR/scripts/sensor_reader.py"
LOG="$REPO_DIR/data/sync.log"

# ── FUNCIONS ──────────────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

# ── INICI ─────────────────────────────────────────────────────────
log "════════ INICI DE SINCRONITZACIÓ ════════"
cd "$REPO_DIR" || { log "ERROR: No s'ha pogut accedir a $REPO_DIR"; exit 1; }

# 1. Llegir el sensor i desar dades
log "→ Llegint sensor DS18B20..."
if python3 "$PYTHON_SCRIPT"; then
    log "✓ Lectura correcta"
else
    log "✗ Error llegint sensor (continuant igualment per sincronitzar el que hi ha)"
fi

# 2. Verificar que hi ha canvis
if git diff --quiet data/temperatures.json 2>/dev/null; then
    log "→ Sense canvis al fitxer. Saltant commit."
    exit 0
fi

# 3. Git add, commit, push
log "→ Afegint fitxer a git..."
git add data/temperatures.json data/sensor.log 2>/dev/null || git add data/temperatures.json

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
MSG="update: lectura sensor $TIMESTAMP"

log "→ Commit: $MSG"
git commit -m "$MSG" --author="SensorBot <sensor@raspberrypi.local>"

log "→ Push a GitHub..."
git push origin main

log "✓ Sincronització completada correctament"
log "═══════════════════════════════════════════"
