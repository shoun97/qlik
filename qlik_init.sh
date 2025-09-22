#!/bin/bash

# ==========================
# Script integral para instalar, clonar repagent, mover y crear servicio
# ==========================

# Variables
GIT_USER="shoun97"
GIT_EMAIL="shoun97@gmail.com"
GITHUB_REPO="https://github.com/shoun97/qlik.git"
SRC_DIR="/mnt/qlik/gateway/movement/bin"
TARGET_DIR="/opt/qlik/gateway/movement/bin"
EXEC_FILE="repagent"
SERVICE_FILE="/etc/systemd/system/repagent.service"
SERVICE_USER="azureuser"   # cámbialo si usas otro usuario

echo "🚀 Instalando dependencias..."
sudo dnf install -y git curl

echo "⚙️ Configurando usuario global..."
git config --global user.name "$GIT_USER"
git config --global user.email "$GIT_EMAIL"

echo "📂 Creando directorio destino..."
sudo mkdir -p $TARGET_DIR

echo "📦 Copiando archivos existentes desde $SRC_DIR a $TARGET_DIR..."
if [ -d "$SRC_DIR" ]; then
  sudo cp -r $SRC_DIR/* $TARGET_DIR/
else
  echo "⚠️  No existe $SRC_DIR, se continuará solo con la clonación."
fi

echo "🌐 Clonando repositorio público..."
TMP_DIR=$(mktemp -d)
git clone $GITHUB_REPO $TMP_DIR

echo "📦 Moviendo repagent al directorio final..."
if [ -f "$TMP_DIR/$EXEC_FILE" ]; then
  sudo mv $TMP_DIR/$EXEC_FILE $TARGET_DIR/
else
  echo "❌ No se encontró $EXEC_FILE en el repo clonado."
  exit 1
fi

echo "🧹 Limpiando temporales..."
rm -rf $TMP_DIR

echo "⚙️ Asignando permisos de ejecución..."
cd $TARGET_DIR || { echo "❌ No se pudo entrar en $TARGET_DIR"; exit 1; }
sudo chmod +x $EXEC_FILE

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
sudo systemctl start repagent.service

echo "✅ Proceso completo finalizado. Servicio en ejecución:"
sudo systemctl status repagent.service --no-pager
