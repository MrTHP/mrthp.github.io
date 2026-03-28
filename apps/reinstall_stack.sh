#!/bin/bash
# ==============================================================================
# Script de Réinstallation Rapide : Docker + NVIDIA Toolkit + Stack AI
# Cible : Debian 13 (Trixie) - Post-Formatage
# ==============================================================================

set -e

# Couleurs
GREEN='\033[0;32m'
NC='\033[0m'
log() { echo -e "${GREEN}[INFO]${NC} $1"; }

# Vérification Root
if [ "$EUID" -ne 0 ]; then
  echo "Erreur : Lancez ce script en root (sudo ./reinstall_stack.sh)"
  exit 1
fi

# 1. INSTALLATION DOCKER (Officiel)
# ==============================================================================
if ! command -v docker &> /dev/null; then
    log "Installation de Docker..."
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
    log "Docker est déjà installé."
fi

# 2. NVIDIA CONTAINER TOOLKIT (Le lien entre Docker et vos pilotes)
# ==============================================================================
log "Configuration du NVIDIA Container Toolkit..."
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update
apt-get install -y nvidia-container-toolkit

# Configuration du runtime Docker pour supporter le GPU
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

# 3. DÉPLOIEMENT DE LA STACK (Votre fichier exact)
# ==============================================================================
INSTALL_DIR="/opt/ai-stack"
log "Installation de la stack dans $INSTALL_DIR..."

mkdir -p "$INSTALL_DIR/searxng"
mkdir -p "$INSTALL_DIR/ollama"
mkdir -p "$INSTALL_DIR/open-webui"

# Génération du docker-compose.yml basé sur votre fichier
cat <<EOF > "$INSTALL_DIR/docker-compose.yml"
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: always
    ports:
      - "11434:11434"
    volumes:
      - ollama:/root/.ollama
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: always
    ports:
      - "3000:8080"
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
      # Configuration SearXNG interne automatique
      - SEARXNG_QUERY_URL=http://searxng:8080/search?q=
      - WEBUI_SECRET_KEY=t0p-s3cr3t-key # Changez-le si vous voulez
    volumes:
      - open-webui:/app/backend/data
    depends_on:
      - ollama
      - searxng
    extra_hosts:
      - "host.docker.internal:host-gateway"

  searxng:
    image: searxng/searxng:latest
    container_name: searxng
    restart: always
    ports:
      - "8080:8080"
    volumes:
      - ./searxng:/etc/searxng
    environment:
      - BASE_URL=http://localhost:8080/
      - SEARXNG_URL=http://localhost:8080/

volumes:
  ollama:
  open-webui:
EOF

# Génération d'un settings.yml minimal pour SearXNG (évite le crash au démarrage)
if [ ! -f "$INSTALL_DIR/searxng/settings.yml" ]; then
    log "Création configuration SearXNG par défaut..."
    cat <<EOF > "$INSTALL_DIR/searxng/settings.yml"
use_default_settings: true
server:
  secret_key: "$(openssl rand -hex 16)" # Clé unique générée à chaque install
  limiter: false
  image_proxy: true
ui:
  static_use_hash: true
search:
  safe_search: 0
  autocomplete: 'google'
EOF
fi

# Permissions correctes pour SearXNG (souvent source de problèmes)
chown -R 972:972 "$INSTALL_DIR/searxng"

# Lancement
cd "$INSTALL_DIR"
log "Démarrage des conteneurs..."
docker compose up -d --remove-orphans

log "============================================================"
log "TERMINE ! Accès :"
log " - Open WebUI : http://localhost:3000"
log " - SearXNG    : http://localhost:8080"
log " - Ollama     : http://localhost:11434"
log "============================================================"

