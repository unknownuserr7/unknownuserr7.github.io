# 🌡️ DS18B20 Temperature Monitor
### Cludi i Abel · SMX 2-A · 2025–26

Sistema de monitoratge de temperatura amb sensor DS18B20, Raspberry Pi i GitHub Pages.

---

## 📋 Índex

1. [Connexió del sensor (protoboard)](#1-connexió-del-sensor-amb-protoboard)
2. [Crear el repositori a GitHub](#2-crear-el-repositori-a-github)
3. [Obtenir el Token de GitHub](#3-obtenir-el-token-de-github)
4. [Configurar GitHub Pages](#4-configurar-github-pages)
5. [Instal·lació a la Raspberry Pi](#5-installació-a-la-raspberry-pi)
6. [Ús manual i automatitzat](#6-ús-manual-i-automatitzat)
7. [Estructura del projecte](#7-estructura-del-projecte)

---

## 1. Connexió del sensor amb protoboard

### Components necessaris
- Sensor DS18B20 (cables: vermell, groc, negre)
- Resistència de **4,7 kΩ** (groc-lila-vermell)
- Protoboard (qualsevol mida)
- 3 cables pont (jumper wires) femella-mascle

### Diagrama de connexió

```
RASPBERRY PI 4                    PROTOBOARD
─────────────────                ─────────────────────────────────
Pin 1  (3.3V)  ●───────────────→  VCC  ──→ Cable VERMELL  (DS18B20)
                                         ─→ [Resistència 4.7kΩ]─┐
Pin 7  (GPIO4) ●───────────────→  DATA ─→ Cable GROC    (DS18B20)─┘
                                          (l'altre extrem de la R)
Pin 6  (GND)   ●───────────────→  GND  ──→ Cable NEGRE   (DS18B20)
─────────────────                ─────────────────────────────────
```

### Pinout Raspberry Pi (vista des del costat USB)

```
    3.3V [1] [2] 5V
   GPIO2 [3] [4] 5V
   GPIO3 [5] [6] GND  ← Cable NEGRE aquí
   GPIO4 [7] [8] ...  ← Cable GROC  aquí
     GND [9] ...
    ...  [1] ... (3.3V = Pin 1, extrem superior esquerre)
```

### Pas a pas de la connexió

1. **Situa el sensor** a la protoboard deixant els 3 cables accessibles.
2. **Resistència pull-up**: connecta la resistència de 4,7 kΩ entre la fila del VCC i la fila del DATA.
3. **Cable VERMELL** (VCC) → Pin 1 de la Raspberry Pi (3,3V).
4. **Cable GROC** (DATA) → Pin 7 de la Raspberry Pi (GPIO 4). **La resistència va connectada aquí també.**
5. **Cable NEGRE** (GND) → Pin 6 de la Raspberry Pi (GND).

> ⚠️ **IMPORTANT**: La resistència pull-up és OBLIGATÒRIA. Sense ella, el sensor no funcionarà o donarà lectures errònies. El protocol 1-Wire ho requereix.

---

## 2. Crear el repositori a GitHub

1. Ves a [github.com](https://github.com) i inicia sessió.
2. Fes clic a **"New repository"** (botó verd a la dreta).
3. Configuració:
   - **Repository name**: `sensor-data` (o el nom que vulguis)
   - **Visibility**: `Public` ← **obligatori per a GitHub Pages gratis**
   - **Add README**: ✅ (marca-ho)
4. Fes clic a **"Create repository"**.
5. **Apunta la URL**: `https://github.com/EL_TEU_USUARI/sensor-data`

---

## 3. Obtenir el Token de GitHub

El token permet que la Raspberry Pi pugui pujar fitxers a GitHub sense contrasenya.

### Crear un Personal Access Token (clàssic)

1. A GitHub, clica la teva **foto de perfil** (dalt a la dreta) → **Settings**.
2. Al menú esquerre, baixa fins a **Developer settings** (al final de tot).
3. Clica **Personal access tokens** → **Tokens (classic)**.
4. Clica **"Generate new token"** → **"Generate new token (classic)"**.
5. Configura el token:
   - **Note**: `raspberry-pi-sensor` (nom descriptiu)
   - **Expiration**: `90 days` o `No expiration`
   - **Scopes** (permisos): ✅ Marca **`repo`** (tot el bloc)
6. Clica **"Generate token"** al final.
7. **COPIA EL TOKEN ARA** — comença per `ghp_...` — no el tornaràs a veure!

```
⚠️  Guarda el token en un lloc segur. Si el perds, hauràs de crear-ne un de nou.
     Format del token: ghp_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

---

## 4. Configurar GitHub Pages

Un cop tens el repositori amb fitxers:

1. Al teu repositori GitHub, clica **Settings** (la pestanya amb l'engranatge).
2. Al menú esquerre, clica **Pages**.
3. A **"Source"**, selecciona:
   - **Branch**: `main`
   - **Folder**: `/ (root)`
4. Clica **Save**.
5. Espera 1-2 minuts i la web estarà disponible a:

```
https://EL_TEU_USUARI.github.io/sensor-data/
```

> 📝 La primera publicació pot trigar 5-10 minuts. Les actualitzacions posteriors triguen ~1 minut.

---

## 5. Instal·lació a la Raspberry Pi

### Opció A: Configuració automàtica (recomanada)

```bash
# 1. Clona el repositori
git clone https://github.com/EL_TEU_USUARI/sensor-data.git ~/sensor-data

# 2. Executa el script de configuració automàtica
cd ~/sensor-data
bash scripts/setup.sh
```

El script et demanarà: usuari de GitHub, nom del repositori i token, i ho configurarà tot automàticament.

---

### Opció B: Configuració manual pas a pas

#### B1. Activar el protocol 1-Wire

```bash
sudo raspi-config
# → Interface Options → 1-Wire → Yes → Finish → Reboot
```

O manualment:
```bash
echo "dtoverlay=w1-gpio" | sudo tee -a /boot/firmware/config.txt
sudo reboot
```

#### B2. Verificar que el sensor es detecta

```bash
ls /sys/bus/w1/devices/
# Ha d'aparèixer alguna cosa com: 28-01234567abcd
```

#### B3. Instal·lar dependències

```bash
sudo apt-get update
sudo apt-get install -y python3-pip git
pip3 install w1thermsensor --break-system-packages
```

#### B4. Configurar Git amb el token

```bash
git config --global user.name "El Teu Nom"
git config --global user.email "elteucorreu@exemple.com"

# Clonar amb el token incrustat a la URL
git clone https://ghp_EL_TEU_TOKEN@github.com/EL_TEU_USUARI/sensor-data.git ~/sensor-data
```

#### B5. Donar permisos d'execució als scripts

```bash
chmod +x ~/sensor-data/scripts/sync_github.sh
chmod +x ~/sensor-data/scripts/setup.sh
```

#### B6. Configurar el cron (3 sincronitzacions diàries)

```bash
crontab -e
# Afegir al final:
0 8  * * * /home/pi/sensor-data/scripts/sync_github.sh >> /home/pi/sensor-data/data/sync.log 2>&1
0 14 * * * /home/pi/sensor-data/scripts/sync_github.sh >> /home/pi/sensor-data/data/sync.log 2>&1
0 20 * * * /home/pi/sensor-data/scripts/sync_github.sh >> /home/pi/sensor-data/data/sync.log 2>&1
```

---

## 6. Ús manual i automatitzat

### Fer una lectura manual

```bash
python3 ~/sensor-data/scripts/sensor_reader.py
```

### Mode simulació (sense sensor físic)

```bash
python3 ~/sensor-data/scripts/sensor_reader.py --simulate
```

### Lectura contínua cada 5 minuts

```bash
python3 ~/sensor-data/scripts/sensor_reader.py --continuous 5
```

### Sincronitzar manualment amb GitHub

```bash
bash ~/sensor-data/scripts/sync_github.sh
```

### Veure els logs

```bash
tail -f ~/sensor-data/data/sync.log
```

---

## 7. Estructura del projecte

```
sensor-data/
├── index.html              ← Web pública (GitHub Pages)
├── data/
│   └── temperatures.json  ← Fitxer de dades del sensor
├── scripts/
│   ├── sensor_reader.py   ← Script Python de lectura
│   ├── sync_github.sh     ← Script de sincronització Git
│   └── setup.sh           ← Configuració automàtica
├── .gitignore
└── README.md
```

### Format del fitxer temperatures.json

```json
[
  {
    "timestamp": "2025-05-13T08:00:00.123456",
    "temperature": 21.34,
    "unit": "celsius"
  }
]
```

---

## Resolució de problemes

| Problema | Solució |
|----------|---------|
| `Sensor DS18B20 no trobat` | Comprova la connexió de cables i la resistència 4.7kΩ |
| `Permission denied` al push | Token caducat o incorrecte. Genera'n un de nou |
| `CRC incorrecte` | Cable mal connectat o resistència pull-up inadequada |
| Web no s'actualitza | Espera 1-2 min. GitHub Pages té retard en la publicació |
| `w1thermsensor` not found | `pip3 install w1thermsensor --break-system-packages` |

---

*Projecte realitzat per **Cludi i Abel** · SMX 2-A · Curs 2025–26*

