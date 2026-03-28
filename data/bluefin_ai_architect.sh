#!/bin/bash

# ==============================================================================
#  BLUEFIN AI ARCHITECT (Pour image Bluefin-DX-Nvidia)
# ==============================================================================

# Pas besoin de sudo pour lancer le script si 'ujust dx-group' a été fait
if ! groups | grep -q "docker"; then
    echo "❌ Erreur : Votre utilisateur n'est pas dans le groupe docker."
    echo "👉 Lancez la commande 'ujust dx-group' dans un terminal, redémarrez, et revenez !"
    exit 1
fi

echo -e "\033[1;34m=== DEPLOIEMENT AI STACK SUR BLUEFIN ===\033[0m"

# Dossier persistant dans le Home (Bluefin est immutable ailleurs)
INSTALL_DIR="$HOME/AI-Stack"
mkdir -p "$INSTALL_DIR/searxng" "$INSTALL_DIR/ollama" "$INSTALL_DIR/open-webui" "$INSTALL_DIR/perplexica"

# --- 1. CONFIGURATION SEARXNG (JSON) ---
# Indispensable pour que Perplexica comprenne les résultats
echo "use_default_settings: true" > "$INSTALL_DIR/searxng/settings.yml"
echo "server: {secret_key: \"$(openssl rand -hex 16)\"}" >> "$INSTALL_DIR/searxng/settings.yml"
echo "search: {formats: [html, json]}" >> "$INSTALL_DIR/searxng/settings.yml"

# --- 2. CREATION DU DOCKER COMPOSE ---
# On met tout dans le même réseau pour qu'ils se voient par leur nom
cat <<EOF > "$INSTALL_DIR/docker-compose.yml"
services:
  # --- OLLAMA (Le Cerveau) ---
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: always
    ports: ["11434:11434"]
    volumes: [ollama_data:/root/.ollama]
    deploy:
      resources:
        reservations:
          devices: [{driver: nvidia, count: 1, capabilities: [gpu]}]

  # --- SEARXNG (Le Moteur de Recherche) ---
  searxng:
    image: searxng/searxng:latest
    container_name: searxng
    restart: always
    ports: ["8080:8080"]
    volumes:
      - ./searxng:/etc/searxng:ro
    environment:
      - BASE_URL=http://localhost:8080/

  # --- OPEN WEBUI (L'Interface Chat) ---
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: always
    ports: ["3000:8080"]
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
    volumes: [openwebui_data:/app/backend/data]
    depends_on: [ollama]

  # --- PERPLEXICA (Le Chercheur AI) ---
  perplexica:
    image: itzcrazykns1337/perplexica:slim-latest
    container_name: perplexica
    restart: always
    ports: ["7000:3000"]
    environment:
      - SEARXNG_API_URL=http://searxng:8080
      - OLLAMA_API_URL=http://ollama:11434
    volumes:
      - perplexica_data:/home/perplexica/data
    depends_on: [ollama, searxng]

volumes:
  ollama_data:
  openwebui_data:
  perplexica_data:
EOF

# --- 3. LANCEMENT ---
cd "$INSTALL_DIR"
echo "[+] Lancement des conteneurs via Docker Compose..."
docker compose up -d

echo ""
echo -e "\033[1;32m✅ INSTALLATION TERMINÉE !\033[0m"
echo "------------------------------------------------"
echo "🚀 OpenWebUI  : http://localhost:3000"
echo "🔍 Perplexica : http://localhost:7000"
echo "⚙️  SearXNG    : http://localhost:8080"
echo "------------------------------------------------"
echo "Note : Dans Perplexica settings, mettez les URL suivantes :"
echo "Ollama Base URL : http://ollama:11434"
echo "(On utilise les noms de conteneurs internes, plus stable que localhost)"
