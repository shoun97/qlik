#!/bin/bash
# ==========================================================
# Clona repagent, copia backup completo a /opt, espejo en /mnt (bin),
# y crea servicio systemd que ejecuta desde /opt.
# ==========================================================

set -euo pipefail

# --- Variables ---
GIT_USER="shoun97"
GIT_EMAIL="shoun97@gmail.com"
GITHUB_REPO="https://github.com/shoun97/qlik.git"

BACKUP_BASE="/opt/qlik.bak.2025-09-05/gateway/movement"   # backup completo (bin, data, etc.)
RUN_BASE="/opt/qlik/gateway/movement"                     # *** base real de ejecución (/opt) ***
RUN_BIN="$RUN_BASE/bin"
RUN_DATA="$RUN_BASE/data"

MNT_BASE="/mnt/qlik/gateway/movement"
MNT_BIN="$MNT_BASE/bin"                                   # espejo opcional

EXEC_FILE="repagent"
AGENTCTL="agentctl"

SERVICE_USER="azureuser"                                  # cámbialo si deseas otro usuario
SERVICE_FILE="/etc/systemd/system/repagent.service"
LOG_FILE="/var/log/repagent.log"

echo "🚀 Instalando dependencias..."
sudo dnf install -y git curl dos2unix rsync

echo "⚙️ Configurando usuario global de git..."
git config --global user.name "$GIT_USER"
git config --global user.email "$GIT_EMAIL"

echo "📂 Creando directorios base..."
sudo mkdir -p "$RUN_BIN" "$RUN_DATA" "$MNT_BIN"

# --- 1) Copiar backup completo a /opt (si existe) ---
if [ -d "$BACKUP_BASE" ]; then
  echo "🗂️ Copiando backup desde $BACKUP_BASE ➜ $RUN_BASE ..."
  sudo rsync -a "$BACKUP_BASE"/ "$RUN_BASE"/
else
  echo "⚠️  No existe $BACKUP_BASE, continúo sin restaurar backup."
fi

# Asegurar que existan bin y data luego del backup
sudo mkdir -p "$RUN_BIN" "$RUN_DATA"

# --- 2) Clonar repo y superponer binarios en /opt/bin ---
TMP_REPO="$(mktemp -d)"
echo "🌐 Clonando repo en $TMP_REPO ..."
git clone "$GITHUB_REPO" "$TMP_REPO"

# Mover (o copiar) repagent y agentctl del repo a /opt/bin
echo "📦 Colocando $EXEC_FILE y $AGENTCTL (si existe) en $RUN_BIN ..."
if [ -f "$TMP_REPO/$EXEC_FILE" ]; then
  sudo rsync -a "$TMP_REPO/$EXEC_FILE" "$RUN_BIN/$EXEC_FILE"
else
  echo "❌ No se encontró $EXEC_FILE en el repo clonado."; sudo rm -rf "$TMP_REPO"; exit 1
fi
[ -f "$TMP_REPO/$AGENTCTL" ] && sudo rsync -a "$TMP_REPO/$AGENTCTL" "$RUN_BIN/$AGENTCTL" || true

echo "🧹 Limpiando temporales del repo..."
rm -rf "$TMP_REPO"

# Normalizar finales de línea y permisos
echo "🔧 Normalizando formato y permisos de ejecución..."
sudo dos2unix "$RUN_BIN/$EXEC_FILE" >/dev/null 2>&1 || true
[ -f "$RUN_BIN/$AGENTCTL" ] && sudo dos2unix "$RUN_BIN/$AGENTCTL" >/dev/null 2>&1 || true
sudo chmod 755 "$RUN_BIN/$EXEC_FILE"
[ -f "$RUN_BIN/$AGENTCTL" ] && sudo chmod 755 "$RUN_BIN/$AGENTCTL" || true

# --- 3) Espejo en /mnt (solo binarios, como venías usando) ---
echo "📤 Espejando binarios en $MNT_BIN ..."
sudo rsync -a "$RUN_BIN"/ "$MNT_BIN"/
sudo chown -R root:root "$MNT_BASE" || true

# --- 4) Log y ownerships ---
echo "🧾 Asegurando archivo de log..."
sudo touch "$LOG_FILE"
sudo chmod 664 "$LOG_FILE"
# No es obligatorio que el log sea del SERVICE_USER; journalctl también conserva logs.

# Si quieres que todo /opt/qlik pertenezca al usuario del servicio, descomenta:
# sudo chown -R "$SERVICE_USER":"$SERVICE_USER" "$RUN_BASE" 2>/dev/null || true

# --- 5) Unit file systemd (ejecuta desde /opt, PID en /opt/data) ---
echo "🛠️ Creando servicio systemd (ejecución desde /opt)..."
sudo tee "$SERVICE_FILE" >/dev/null <<EOF
[Unit]
Description=Servicio repagent (Qlik Data Movement Gateway)
After=network.target

[Service]
Type=forking
WorkingDirectory=$RUN_BASE
ExecStart=/bin/bash -lc '$RUN_BIN/$EXEC_FILE start'
ExecStop=/bin/bash -lc '$RUN_BIN/$EXEC_FILE stop'
PIDFile=$RUN_DATA/repagent.pid
Restart=on-failure
RestartSec=10
User=$SERVICE_USER
LimitNOFILE=65535
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE

[Install]
WantedBy=multi-user.target
EOF

echo "🔄 Recargando/activando servicio..."
sudo systemctl daemon-reload
sudo systemctl enable repagent
sudo systemctl restart repagent || true

echo "📌 Estado del servicio:"
sudo systemctl status repagent --no-pager || true

echo "📜 Últimas líneas del log:"
sudo tail -n 100 "$LOG_FILE" 2>/dev/null || true

echo "✅ Listo. Ejecutando desde $RUN_BIN, datos en $RUN_DATA. Espejo de binarios en $MNT_BIN."
