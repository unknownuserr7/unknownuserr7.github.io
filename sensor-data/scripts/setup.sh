#!/bin/bash
# ════════════════════════════════════════════════════════════════
# setup.sh
# Configuració automàtica completa del sistema de sensor
#
# Executa: bash setup.sh
# Autors: Cludi i Abel · SMX 2-A · 2025-26
# ════════════════════════════════════════════════════════════════

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'; BOLD='\033[1m'

banner() {
  echo -e "${BLUE}"
  echo "  ████████╗███████╗███╗   ███╗██████╗  ██████╗ "
  echo "  ╚══██╔══╝██╔════╝████╗ ████║██╔══██╗██╔═══██╗"
  echo "     ██║   █████╗  ██╔████╔██║██████╔╝██║   ██║"
  echo "     ██║   ██╔══╝  ██║╚██╔╝██║██╔═══╝ ██║   ██║"
  echo "     ██║   ███████╗██║ ╚═╝ ██║██║     ╚██████╔╝"
  echo "     ╚═╝   ╚══════╝╚═╝     ╚═╝╚═╝      ╚═════╝ "
  echo ""
  echo "  DS18B20 Monitor · Setup Script · SMX 2-A 2025-26"
  echo -e "${NC}"
}

ok()   { echo -e "  ${GREEN}✓${NC} $*"; }
err()  { echo -e "  ${RED}✗ ERROR:${NC} $*"; exit 1; }
info() { echo -e "  ${YELLOW}→${NC} $*"; }
step() { echo -e "\n${BOLD}$*${NC}"; }

banner

REPO_DIR="$HOME/sensor-data"

# ── PAS 1: Demanar configuració ───────────────────────────────────
step "PAS 1 · Configuració de GitHub"
echo ""
read -p "  Nom d'usuari de GitHub: " GH_USER
read -p "  Nom del repositori (ex: sensor-data): " GH_REPO
read -p "  El teu nom complet (ex: Cludi Cognoms): " GH_NAME
read -p "  El teu correu de GitHub: " GH_EMAIL
echo ""
read -p "  Token d'accés personal de GitHub (ghp_...): " GH_TOKEN
echo ""

if [ -z "$GH_USER" ] || [ -z "$GH_REPO" ] || [ -z "$GH_TOKEN" ]; then
  err "Falten dades obligatòries (usuari, repositori o token)."
fi

GH_URL="https://${GH_TOKEN}@github.com/${GH_USER}/${GH_REPO}.git"

# ── PAS 2: Actualitzar el sistema ─────────────────────────────────
step "PAS 2 · Actualització del sistema"
info "Actualitzant paquets..."
sudo apt-get update -qq && ok "Sistema actualitzat"

# ── PAS 3: Activar 1-Wire ────────────────────────────────────────
step "PAS 3 · Activació del protocol 1-Wire"
if grep -q "dtoverlay=w1-gpio" /boot/config.txt 2>/dev/null || \
   grep -q "dtoverlay=w1-gpio" /boot/firmware/config.txt 2>/dev/null; then
  ok "1-Wire ja estava activat"
else
  info "Afegint 1-Wire a la configuració..."
  CONFIG="/boot/firmware/config.txt"
  [ -f "/boot/config.txt" ] && CONFIG="/boot/config.txt"
  echo "dtoverlay=w1-gpio" | sudo tee -a "$CONFIG" > /dev/null
  ok "1-Wire activat (caldrà reiniciar)"
fi

# Carregar mòduls ara sense reiniciar
sudo modprobe w1-gpio 2>/dev/null || true
sudo modprobe w1-therm 2>/dev/null || true

# ── PAS 4: Instal·lar Python ──────────────────────────────────────
step "PAS 4 · Dependències Python"
info "Instal·lant python3-pip i w1thermsensor..."
sudo apt-get install -y python3-pip git 2>/dev/null | grep -E "installed|upgraded" | head -5
pip3 install w1thermsensor --break-system-packages 2>/dev/null | tail -1
ok "Dependències instal·lades"

# ── PAS 5: Configurar Git ─────────────────────────────────────────
step "PAS 5 · Configuració de Git"
git config --global user.name  "$GH_NAME"
git config --global user.email "$GH_EMAIL"
git config --global credential.helper store
ok "Identitat Git configurada: $GH_NAME <$GH_EMAIL>"

# ── PAS 6: Clonar o actualitzar el repositori ────────────────────
step "PAS 6 · Repositori GitHub"
if [ -d "$REPO_DIR/.git" ]; then
  info "Repositori ja clonat. Actualitzant..."
  cd "$REPO_DIR"
  git remote set-url origin "$GH_URL"
  git pull origin main
  ok "Repositori actualitzat"
else
  info "Clonant repositori..."
  git clone "$GH_URL" "$REPO_DIR" || err "No s'ha pogut clonar. Comprova el token i el repositori."
  ok "Repositori clonat a $REPO_DIR"
fi

cd "$REPO_DIR"
mkdir -p data
chmod +x scripts/sync_github.sh

# Crear fitxer de dades inicial si no existeix
if [ ! -f "data/temperatures.json" ]; then
  echo "[]" > data/temperatures.json
  ok "Fitxer temperatures.json creat"
fi

# Verificar sensor
step "PAS 7 · Comprovació del sensor"
SENSOR=$(ls /sys/bus/w1/devices/28-* 2>/dev/null | head -1)
if [ -n "$SENSOR" ]; then
  TEMP_RAW=$(cat "$SENSOR/w1_slave" 2>/dev/null | grep "t=" | sed 's/.*t=//')
  TEMP=$(echo "scale=2; $TEMP_RAW / 1000" | bc 2>/dev/null || echo "?")
  ok "Sensor DS18B20 detectat: $(basename $SENSOR)"
  ok "Temperatura actual: ${TEMP}°C"
else
  echo -e "  ${YELLOW}⚠${NC}  Sensor no detectat. Comprova la connexió al GPIO4."
  echo -e "     Si acabes d'activar 1-Wire, reinicia amb: sudo reboot"
fi

# ── PAS 8: Configurar cron ────────────────────────────────────────
step "PAS 8 · Automatització amb cron (3 vegades/dia)"
CRON_CMD="$REPO_DIR/scripts/sync_github.sh >> $REPO_DIR/data/sync.log 2>&1"
CRON_ENTRY_1="0 8  * * * $CRON_CMD"
CRON_ENTRY_2="0 14 * * * $CRON_CMD"
CRON_ENTRY_3="0 20 * * * $CRON_CMD"

# Eliminar entrades velles i afegir-ne de noves
CURRENT=$(crontab -l 2>/dev/null | grep -v "sync_github" || true)
{
  echo "$CURRENT"
  echo "$CRON_ENTRY_1"
  echo "$CRON_ENTRY_2"
  echo "$CRON_ENTRY_3"
} | crontab -
ok "Cron configurat: 08:00, 14:00 i 20:00 cada dia"

# ── PAS 9: Primera lectura i push ─────────────────────────────────
step "PAS 9 · Primera lectura i sincronització"
info "Fent primera lectura del sensor..."
python3 "$REPO_DIR/scripts/sensor_reader.py" && ok "Lectura correcta"

info "Pujant a GitHub..."
cd "$REPO_DIR"
git add data/temperatures.json
git commit -m "setup: primera lectura des de Raspberry Pi" 2>/dev/null || true
git push origin main && ok "Pujat a GitHub correctament"

# ── RESUM ─────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✓  CONFIGURACIÓ COMPLETADA CORRECTAMENT!${NC}"
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Repositori:  ${BLUE}https://github.com/$GH_USER/$GH_REPO${NC}"
echo -e "  Web pública: ${BLUE}https://$GH_USER.github.io/$GH_REPO/${NC}"
echo ""
echo -e "  Sincronitzacions automàtiques: ${YELLOW}08:00, 14:00, 20:00${NC}"
echo ""
echo -e "  Comandes útils:"
echo -e "    Lectura manual:  ${YELLOW}python3 $REPO_DIR/scripts/sensor_reader.py${NC}"
echo -e "    Sincronitzar:    ${YELLOW}bash $REPO_DIR/scripts/sync_github.sh${NC}"
echo -e "    Veure logs:      ${YELLOW}tail -f $REPO_DIR/data/sync.log${NC}"
echo ""
echo -e "  ${RED}IMPORTANT:${NC} Recorda activar GitHub Pages al repositori!"
echo -e "  Settings → Pages → Branch: main → Folder: / (root)"
echo ""
