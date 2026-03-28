#!/usr/bin/env bash
# ------------------------------------------------------------
# searxng.sh – Déploiement de SearXNG (Docker) après le reboot
# ------------------------------------------------------------
# 1. Pull de l'image officielle searxng/searxng:latest
# 2. Création du répertoire ~/searxng, du .env et du docker‑compose.yml
# 3. Démarrage du stack (docker compose up -d)
# 4. Ouverture du navigateur par défaut sur http://127.0.0.1:8080
# ------------------------------------------------------------

set -euo pipefail

log() { echo -e "\e[32m[+] $*\e[0m"; }
error() { echo -e "\e[31m[-] $*\e[0m" >&2; exit 1; }

BASE_DIR="${HOME}/searxng"
ENV_FILE="${BASE_DIR}/.env"
COMPOSE_FILE="${BASE_DIR}/docker-compose.yml"
SEARXNG_IMG="searxng/searxng:latest"

# ----- 1. Pull de l'image -----
log "Pull de l'image Docker SearXNG (${SEARXNG_IMG})..."
docker pull "${SEARXNG_IMG}"

# ----- 2. Préparer le répertoire de travail -----
log "Création du répertoire de travail : ${BASE_DIR}"
mkdir -p "${BASE_DIR}"
cd "${BASE_DIR}"

# ----- 2a. Secret aléatoire -----
log "Génération du secret SearXNG..."
SECRET=$(openssl rand -hex 32)
cat > "${ENV_FILE}" <<EOF
SEARXNG_SECRET=${SECRET}
EOF
log ".env créé."

# ----- 2b. docker‑compose.yml -----
log "Création du fichier docker‑compose.yml..."
cat > "${COMPOSE_FILE}" <<'EOF'
version: "3.8"

services:
  redis:
    image: valkey/valkey:8-alpine
    restart: unless-stopped

  searxng:
    image: searxng/searxng:latest
    depends_on:
      - redis
    env_file:
      - .env
    environment:
      REDIS_URL: redis://redis:6379/0
      BASE_URL: http://127.0.0.1:8080/
    ports:
      - "127.0.0.1:8080:8080"
    restart: unless-stopped
EOF
log "docker‑compose.yml créé."

# ----- 3. Démarrage du stack -----
log "Démarrage du stack Docker (mode détaché)…"
if docker compose version >/dev/null 2>&1; then
    docker compose up -d
else
    sudo docker-compose up -d
fi

log "✅ SearXNG est maintenant en cours d’exécution."

# ----- 4. Ouverture du navigateur -----
BROWSER_URL="http://127.0.0.1:8080"
log "Ouverture du navigateur par défaut sur ${BROWSER_URL} …"

# Méthodes compatibles avec la plupart des environnements de bureau
if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "${BROWSER_URL}" &
elif command -v gnome-open >/dev/null 2>&1; then
    gnome-open "${BROWSER_URL}" &
elif command -v open >/dev/null 2>&1; then   # macOS (au cas où)
    open "${BROWSER_URL}" &
else
    warn "Impossible de détecter une commande d'ouverture de navigateur."
    echo "Ouvrez manuellement ${BROWSER_URL} dans votre navigateur préféré."
fi

log "Installation terminée. Bonne recherche !"
