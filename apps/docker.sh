#!/usr/bin/env bash
# ------------------------------------------------------------
# docker.sh – Installation et configuration de Docker
# ------------------------------------------------------------
# 1. Installe docker.io et docker‑compose (si besoin)
# 2. Active le service Docker
# 3. Ajoute l'utilisateur actuel au groupe docker
# 4. Redémarre la machine
# ------------------------------------------------------------

set -euo pipefail

log() { echo -e "\e[32m[+] $*\e[0m"; }
warn() { echo -e "\e[33m[!] $*\e[0m"; }

# ----- 1. Installation de Docker -----
log "Vérification de Docker..."
if ! command -v docker >/dev/null 2>&1; then
    log "Docker absent – installation via apt..."
    sudo apt update
    sudo apt install -y docker.io docker-compose
else
    log "Docker déjà installé."
fi

# ----- 2. Activation du service Docker -----
log "Activation et démarrage du service Docker..."
sudo systemctl enable --now docker

# ----- 3. Ajout de l'utilisateur au groupe docker -----
if groups "$USER" | grep -qw docker; then
    log "L'utilisateur $USER appartient déjà au groupe docker."
else
    log "Ajout de $USER au groupe docker..."
    sudo usermod -aG docker "$USER"
    warn "Le changement de groupe nécessite un redémarrage."
fi

# ----- 4. Redémarrage -----
log "Redémarrage du système dans 5 secondes..."
sleep 5
sudo systemctl reboot
