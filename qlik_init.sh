#!/bin/bash

# ==========================
# Script integral para instalar Git, clonar repo, mover y ejecutar
# ==========================

# ===== Variables a personalizar =====
GIT_USER="shoun97"
GIT_EMAIL="shoun97@gmail.com"
GITHUB_TOKEN="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"
GITHUB_REPO="https://github.com/shoun97/qlik.git"
TARGET_DIR="/mnt/qlik/gateway/movement/bin"
EXEC_FILE="repagent"   
# ====================================

echo "🚀 Instalando Git..."
sudo dnf install -y git

echo "⚙️ Configurando usuario global..."
git config --global user.name "$GIT_USER"
git config --global user.email "$GIT_EMAIL"

echo "🔑 Configurando credenciales..."
git config --global credential.helper store
CRED_FILE="$HOME/.git-credentials"
echo "https://$GIT_USER:$GITHUB_TOKEN@github.com" > $CRED_FILE
chmod 600 $CRED_FILE

echo "📂 Creando directorio destino..."
sudo mkdir -p $TARGET_DIR

echo "🌐 Clonando repositorio temporal..."
TMP_DIR=$(mktemp -d)
git clone $GITHUB_REPO $TMP_DIR

echo "📦 Moviendo archivos al directorio final..."
sudo mv $TMP_DIR/* $TARGET_DIR/

echo "🧹 Limpiando temporales..."
rm -rf $TMP_DIR

echo "⚙️ Asignando permisos de ejecución..."
cd $TARGET_DIR || { echo "❌ No se pudo entrar en $TARGET_DIR"; exit 1; }
chmod +x $EXEC_FILE

echo "🚀 Ejecutando $EXEC_FILE ..."
./$EXEC_FILE

echo "✅ Proceso completo finalizado. Repo disponible en: $TARGET_DIR"
