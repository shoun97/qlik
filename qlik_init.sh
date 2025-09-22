#!/bin/bash

# ==========================
# Script integral para instalar, clonar repagent, mover a /mnt y crear servicio
# ==========================

# Variables
GIT_USER="shoun97"
GIT_EMAIL="shoun97@gmail.com"
GITHUB_REPO="https://github.com/shoun97/qlik.git"
SRC_DIR="/opt/qlik.bak.2025-09-05/gateway/movement/bin"
TARGET_DIR="/mnt/qlik/gateway/movement/bin"
EXEC_FILE="repagent"
SERVICE_FILE="/etc/systemd/system/repagent.service"
SERVICE_USER="azureuser"   # cámbialo si usas otro usuario

echo "🚀 Instalando dependencias..."
sudo dnf install -y git curl

echo "⚙️ Configurando usuario global..."
git config --global user.name "$GIT_USER"
git config --global user.email "$GIT_EMAIL"

echo "📂 Creando directorios origen y destino..."
sudo mkdir -p $SRC_DIR
sudo mkdir -p $TARGET_DIR

echo "🌐 Clonando repositorio público en $SRC_DIR..."
sudo git clone $GITHUB_REPO $SRC_DIR/tmp-repo

echo "📦 Moviendo repagent a $SRC_DIR..."
if [ -f "$SRC_DIR/tmp-repo/$EXEC_FILE" ]; then
  sudo mv $SRC_DIR/tmp-repo/$EXEC_FILE $SRC_DIR/
else
  echo "❌ No se encontró $EXEC_FILE en el repo clonado."
  exit 1
fi

echo "🧹 Limpiando temporales..."
sudo rm -rf $SRC_DIR/tmp-repo

echo "📤 Copiando todo desde $SRC_DIR hacia $TARGET_DIR..."
sudo cp -r $SRC_DIR/* $TARGET_DIR/

echo "⚙️ Ajustando permisos y ownership en $TARGET_DIR..."
cd $TARGET_DIR || { echo "❌ No se pudo entrar en $TARGET_DIR"; exit 1; }
sudo chmod 755 $TARGET_DIR/$EXEC_FILE $TARGET_DIR/agentctl 2>/dev/null || true
sudo chown -R root:root /mnt/qlik/gateway/movement

echo "🛠️ Creando servicio systemd..."
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=Servicio repagent
After=network.target

[Service]
Type=simple
ExecStart=$TARGET_DIR/$EXEC_FILE
WorkingDirectory=$TARGET_DIR
Restart=always
RestartSec=5
User=$SERVICE_USER

[Install]
WantedBy=multi-user.target
EOL

echo "🔄 Recargando systemd y habilitando servicio..."
sudo systemctl daemon-reload
sudo systemctl enable repagent.service
sudo systemctl restart repagent.service

echo "✅ Proceso completo finalizado. Servicio en ejecución:"
sudo systemctl status repagent.service --no-pager
