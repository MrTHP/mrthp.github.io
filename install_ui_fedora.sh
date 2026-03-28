#!/bin/bash
set -e

# ============================================================
#  INSTALLATION AUTOMATISÉE : OLLAMA + DOCKER UI (FEDORA 43+)
#  Correction des conflits Firewalld, SELinux et Permissions
# ============================================================

INSTALL_DIR="/opt/ai-stack"
USER_REAL=$(whoami)

echo -e "\033[1;34m[..] Nettoyage des conflits potentiels (Podman)...\033[0m"
sudo dnf remove -y podman buildah || true

# 1. INSTALLATION DOCKER ENGINE
if ! command -v docker &> /dev/null; then
    echo "Configuration du dépôt Docker..."
    sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo

    echo "Installation de Docker Engine..."
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Activation immédiate
    sudo systemctl enable --now docker

    # Correction des droits sur le socket pour éviter le "Permission Denied"
    sudo chmod 666 /var/run/docker.sock
    sudo usermod -aG docker $USER_REAL
fi

# 2. CONFIGURATION DU PARE-FEU (FIREWALLD)
echo "Configuration intelligente du pare-feu..."
# On ouvre les ports plutôt que de lier l'interface pour éviter le ZONE_CONFLICT
sudo firewall-cmd --permanent --add-port=3000/tcp   # OpenWebUI
sudo firewall-cmd --permanent --add-port=7000/tcp   # Perplexica
sudo firewall-cmd --permanent --add-port=8080/tcp   # SearXNG
sudo firewall-cmd --permanent --add-port=11434/tcp  # Ollama API
sudo firewall-cmd --reload

# 3. CONFIGURATION OLLAMA (ÉCOUTE RÉSEAU)
if systemctl is-active --quiet ollama; then
    echo "Configuration d'Ollama pour accepter les connexions Docker..."
    sudo mkdir -p /etc/systemd/system/ollama.service.d
    cat <<EOF | sudo tee /etc/systemd/system/ollama.service.d/override.conf
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
Environment="OLLAMA_ORIGINS=*"
EOF
    sudo systemctl daemon-reload
    sudo systemctl restart ollama
fi

# 4. PRÉPARATION DES DOSSIERS ET SELINUX
echo "Préparation du dossier $INSTALL_DIR..."
sudo mkdir -p "$INSTALL_DIR/searxng"
sudo chown -R $USER_REAL:$USER_REAL "$INSTALL_DIR"

# Application du contexte SELinux pour que Docker puisse lire/écrire dans /opt
sudo chcon -Rt svirt_sandbox_file_t "$INSTALL_DIR" || true

# Config SearXNG
echo "use_default_settings: true" > "$INSTALL_DIR/searxng/settings.yml"
echo "server: {secret_key: \"$(openssl rand -hex 16)\"}" >> "$INSTALL_DIR/searxng/settings.yml"
echo "search: {formats: [html, json]}" >> "$INSTALL_DIR/searxng/settings.yml"

# 5. GÉNÉRATION DU DOCKER-COMPOSE
cat <<EOF > "$INSTALL_DIR/docker-compose.yml"
services:
  searxng:
    image: searxng/searxng:latest
    restart: always
    ports: ["8080:8080"]
    volumes: ["$INSTALL_DIR/searxng:/etc/searxng"]
    environment:
      - BASE_URL=http://localhost:8080/

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    restart: always
    ports: ["3000:8080"]
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal:11434
      - SEARXNG_QUERY_URL=http://searxng:8080/search?q=
    volumes: ["open-webui:/app/backend/data"]

  perplexica:
    image: itzcrazykns1337/perplexica:slim-latest
    restart: always
    ports: ["7000:3000"]
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      - SEARXNG_API_URL=http://searxng:8080
      - OLLAMA_API_URL=http://host.docker.internal:11434
    volumes: ["perplexica-data:/home/perplexica/data"]

volumes:
  open-webui:
  perplexica-data:
EOF

# 6. LANCEMENT FINAL
echo "Lancement des services Docker..."
cd "$INSTALL_DIR"
docker compose down || true # Nettoie si une version précédente existe
docker compose up -d

echo -e "\n\033[1;32m✅ TOUT EST PRÊT !\033[0m"
echo "------------------------------------------------"
echo "🔗 OpenWebUI : http://localhost:3000"
echo "🔗 Perplexica: http://localhost:7000"
echo "------------------------------------------------"
echo "⚠️  NOTE : Si c'est la première installation de Docker,"
echo "   tapez 'newgrp docker' ou redémarrez votre session."
