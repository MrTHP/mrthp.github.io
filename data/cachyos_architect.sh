#!/bin/bash

# ==============================================================================
#  CACHYOS / ARCH ARCHITECT - v1.0 (Special Edition)
# ==============================================================================

# --- 1. INITIALISATION ---

if [ "$EUID" -ne 0 ]; then
  echo "Erreur : Lancez ce script avec sudo !"
  echo "Usage: sudo ./cachyos_architect.sh"
  exit 1
fi

REAL_USER=$SUDO_USER
if [ -z "$REAL_USER" ]; then REAL_USER=$(whoami); fi
REAL_HOME=$(getent passwd $REAL_USER | cut -d: -f6)

# Vérification des dépendances de base
if ! command -v whiptail &> /dev/null; then
    pacman -Sy --noconfirm libnewt
fi

# Détection du Helper AUR (Paru est par défaut sur CachyOS, sinon Yay)
AUR_HELPER=""
if command -v paru &> /dev/null; then
    AUR_HELPER="paru"
elif command -v yay &> /dev/null; then
    AUR_HELPER="yay"
else
    echo "Ni paru ni yay détecté. Installation de yay-bin..."
    sudo -u $REAL_USER bash -c "cd /tmp && git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si --noconfirm"
    AUR_HELPER="yay"
fi

BACKTITLE="CachyOS Architect - v1.0 (User: $REAL_USER)"

# --- 2. FONCTIONS UTILITAIRES ---

function confirm_action() {
    if whiptail --title "$1" --backtitle "$BACKTITLE" --yesno "$2\n\nVoulez-vous procéder ?" 12 70; then
        return 0
    else
        return 1
    fi
}

function run_with_logs() {
    clear
    echo -e "\033[1;33m[ACTION] $1...\033[0m"
    echo "-----------------------------------------------------"
    eval "$2"
    STATUS=$?
    echo "-----------------------------------------------------"
    if [ $STATUS -eq 0 ]; then
        echo -e "\n\033[1;32m✅ Opération terminée.\033[0m"
    else
        echo -e "\n\033[1;31m❌ Erreur détectée.\033[0m"
    fi
    echo -e "Appuyez sur \033[1;37mENTRÉE\033[0m pour revenir au menu."
    read -r
}

# Fonction pour installer depuis l'AUR sans être root (Arch security)
function aur_install() {
    sudo -u $REAL_USER $AUR_HELPER -S --noconfirm $1
}

# --- 3. MODULES ---

function module_system() {
    if confirm_action "Mise à jour Système" "CachyOS est une Rolling Release.\nCeci va lancer une mise à jour complète (pacman -Syu)."; then
        
        # Activation Multilib (Pour Steam/Gaming)
        if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
            echo "[+] Activation du dépôt Multilib..."
            echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
        fi
        
        run_with_logs "Mise à jour globale" "pacman -Syu --noconfirm && pacman -S --noconfirm base-devel git wget curl"
    fi
}

function module_gpu() {
    CHOIX_GPU=$(whiptail --title "Installation GPU" --backtitle "$BACKTITLE" --menu "Choisissez votre driver :" 15 70 4 \
    "1" "NVIDIA (Propriétaire - Recommandé CachyOS)" \
    "2" "AMD (Mesa + Vulkan)" \
    "3" "INTEL (Mesa + Accélération Vidéo)" \
    "4" "Retour" 3>&1 1>&2 2>&3)
    
    if [ $? -eq 0 ]; then
        case $CHOIX_GPU in
            1)
                # Nvidia DKMS est mieux pour les kernels custom CachyOS
                run_with_logs "Installation NVIDIA" "pacman -S --noconfirm nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings opencl-nvidia"
                ;;
            2)
                run_with_logs "Installation AMD" "pacman -S --noconfirm mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon libva-mesa-driver"
                ;;
            3)
                CHOIX_INTEL=$(whiptail --title "Configuration Intel" --menu "Quel génération de CPU avez-vous ?" 15 70 2 \
                "1" "Legacy/Ancien (Gen 4 Haswell - T440p)" \
                "2" "Moderne (Gen 8+ / Xe Graphics)" 3>&1 1>&2 2>&3)
                
                if [ $? -eq 0 ]; then
                    if [ "$CHOIX_INTEL" == "1" ]; then
                        # T440p utilise i965/legacy
                        run_with_logs "Installation Intel Legacy (T440p)" "pacman -S --noconfirm mesa lib32-mesa intel-media-driver libva-intel-driver vulkan-intel"
                    else
                        run_with_logs "Installation Intel Moderne" "pacman -S --noconfirm mesa lib32-mesa intel-media-driver vulkan-intel"
                    fi
                fi
                ;;
        esac
    fi
}

function module_optimization() {
    SELECTION=$(whiptail --title "Optimisation & Laptop" --backtitle "$BACKTITLE" --checklist "Outils pour Laptop (CachyOS est déjà optimisé) :" 20 75 5 \
    "MICROCODE" "Intel Microcode (Indispensable CPU)" ON \
    "TLP" "TLP (Gestion Batterie)" ON \
    "THERMALD" "Thermald (Gestion Chauffe CPU Intel)" ON \
    "BLUETOOTH" "Support Bluetooth (Bluez)" ON \
    3>&1 1>&2 2>&3)

    CMD=""
    if [[ $SELECTION == *"MICROCODE"* ]]; then CMD="$CMD pacman -S --noconfirm intel-ucode;"; fi
    if [[ $SELECTION == *"TLP"* ]]; then CMD="$CMD pacman -S --noconfirm tlp && systemctl enable --now tlp;"; fi
    if [[ $SELECTION == *"THERMALD"* ]]; then CMD="$CMD pacman -S --noconfirm thermald && systemctl enable --now thermald;"; fi
    if [[ $SELECTION == *"BLUETOOTH"* ]]; then CMD="$CMD pacman -S --noconfirm bluez bluez-utils && systemctl enable --now bluetooth;"; fi

    if [ -n "$CMD" ]; then run_with_logs "Installation Optimisations" "$CMD"; fi
}

function module_gaming() {
    SELECTION=$(whiptail --title "Gaming Setup" --backtitle "$BACKTITLE" --checklist "Outils Gaming :" 20 70 6 \
    "STEAM" "Steam + Libs 32bit" ON \
    "GAMEMODE" "Gamemode (Feral)" ON \
    "MANGOHUD" "MangoHud (FPS Overlay)" ON \
    "PROTON" "ProtonPlus (Gestionnaire Proton - AUR)" OFF \
    3>&1 1>&2 2>&3)

    CMD=""
    if [[ $SELECTION == *"STEAM"* ]]; then
        CMD="$CMD pacman -S --noconfirm steam ttf-liberation;"
    fi
    if [[ $SELECTION == *"GAMEMODE"* ]]; then
        CMD="$CMD pacman -S --noconfirm gamemode lib32-gamemode;"
    fi
     if [[ $SELECTION == *"MANGOHUD"* ]]; then
        CMD="$CMD pacman -S --noconfirm mangohud lib32-mangohud;"
    fi

    if [ -n "$CMD" ]; then run_with_logs "Installation Gaming Base" "$CMD"; fi

    # Installation AUR séparée
    if [[ $SELECTION == *"PROTON"* ]]; then
        echo "Installation ProtonPlus via AUR..."
        sudo -u $REAL_USER $AUR_HELPER -S --noconfirm protonplus
    fi
}

function module_browsers() {
    SELECTION=$(whiptail --title "Navigateurs Web" --backtitle "$BACKTITLE" --checklist "Installation :" 20 75 5 \
    "CHROME" "Google Chrome (AUR)" OFF \
    "FIREFOX" "Firefox (Officiel)" OFF \
    "ZEN" "Zen Browser (AUR)" OFF \
    "TOR" "Tor Browser Launcher" OFF \
    3>&1 1>&2 2>&3)
    
    if [[ $SELECTION == *"FIREFOX"* ]]; then
        run_with_logs "Installation Firefox" "pacman -S --noconfirm firefox"
    fi
    if [[ $SELECTION == *"TOR"* ]]; then
        run_with_logs "Installation Tor" "pacman -S --noconfirm torbrowser-launcher"
    fi
    
    # Installation AUR
    if [[ $SELECTION == *"CHROME"* ]]; then
        echo "Installation Google Chrome (AUR)..."
        sudo -u $REAL_USER $AUR_HELPER -S --noconfirm google-chrome
    fi
    if [[ $SELECTION == *"ZEN"* ]]; then
        echo "Installation Zen Browser (AUR)..."
        sudo -u $REAL_USER $AUR_HELPER -S --noconfirm zen-browser-bin
    fi
}

function module_social() {
    SELECTION=$(whiptail --title "Social Apps" --backtitle "$BACKTITLE" --checklist "Sélection :" 20 70 4 \
    "DISCORD" "Discord (Officiel)" OFF \
    "TELEGRAM" "Telegram Desktop (Officiel)" OFF \
    3>&1 1>&2 2>&3)

    CMD=""
    if [[ $SELECTION == *"DISCORD"* ]]; then CMD="$CMD pacman -S --noconfirm discord;"; fi
    if [[ $SELECTION == *"TELEGRAM"* ]]; then CMD="$CMD pacman -S --noconfirm telegram-desktop;"; fi

    if [ -n "$CMD" ]; then run_with_logs "Installation Social" "$CMD"; fi
}

function module_software() {
    SELECTION=$(whiptail --title "Logiciels Utiles" --backtitle "$BACKTITLE" --checklist "Apps :" 20 70 8 \
    "VLC" "Lecteur Média VLC" OFF \
    "OBS" "OBS Studio" OFF \
    "GIMP" "Editeur Image GIMP" OFF \
    "QBIT" "qBittorrent" OFF \
    "VSCODE" "Visual Studio Code (AUR)" OFF \
    "FASTFETCH" "Fastfetch" OFF \
    3>&1 1>&2 2>&3)

    CMD=""
    PACKAGES=""
    if [[ $SELECTION == *"VLC"* ]]; then PACKAGES="$PACKAGES vlc"; fi
    if [[ $SELECTION == *"GIMP"* ]]; then PACKAGES="$PACKAGES gimp"; fi
    if [[ $SELECTION == *"QBIT"* ]]; then PACKAGES="$PACKAGES qbittorrent"; fi
    if [[ $SELECTION == *"OBS"* ]]; then PACKAGES="$PACKAGES obs-studio"; fi
    if [[ $SELECTION == *"FASTFETCH"* ]]; then PACKAGES="$PACKAGES fastfetch"; fi
    
    if [ -n "$PACKAGES" ]; then CMD="$CMD pacman -S --noconfirm $PACKAGES;"; fi
    
    if [ -n "$CMD" ]; then run_with_logs "Installation Logiciels (Repo)" "$CMD"; fi

    if [[ $SELECTION == *"VSCODE"* ]]; then
        echo "Installation VS Code (AUR)..."
        sudo -u $REAL_USER $AUR_HELPER -S --noconfirm visual-studio-code-bin
    fi
}

function module_ai_stack() {
    # AJOUT OPTION 3: CPU ONLY (Pour votre T440p)
    CHOIX_AI_GPU=$(whiptail --title "AI Stack Configuration" --backtitle "$BACKTITLE" --menu "Quel type d'accélération GPU utiliser ?" 15 70 3 \
    "1" "NVIDIA (CUDA via Nvidia-Toolkit)" \
    "2" "AMD (ROCm)" \
    "3" "CPU ONLY (Intel HD / Pas de GPU dédié)" 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then return; fi # Annuler

    # Question pour Perplexica
    INSTALL_PERPLEXICA=false
    if whiptail --title "Perplexica AI" --backtitle "$BACKTITLE" --yesno "Voulez-vous aussi installer Perplexica (Moteur de recherche AI) ?\n\nIl sera configuré sur le port 7000." 12 70; then
        INSTALL_PERPLEXICA=true
    fi

    if confirm_action "Installation AI Stack" "Installation Docker et Stack AI sur Arch/CachyOS."; then
        
        # 1. Installation Docker sur Arch
        echo "[+] Installation Docker..."
        pacman -S --noconfirm docker docker-compose
        systemctl enable --now docker
        usermod -aG docker $REAL_USER

        INSTALL_DIR="/opt/ai-stack"
        mkdir -p "$INSTALL_DIR/searxng" "$INSTALL_DIR/ollama" "$INSTALL_DIR/open-webui"
        
        STACK_SCRIPT=""

        if [ "$CHOIX_AI_GPU" == "1" ]; then
            # === NVIDIA (Arch Specific) ===
            echo "[+] Configuration NVIDIA Container Toolkit (AUR)..."
            # Installation via AUR Helper en tant que user
            sudo -u $REAL_USER $AUR_HELPER -S --noconfirm nvidia-container-toolkit
            sudo nvidia-ctk runtime configure --runtime=docker
            sudo systemctl restart docker

            # CORRECTIF SYNTAXE YAML
            cat <<EOF > "$INSTALL_DIR/docker-compose.yml"
services:
  ollama:
    image: ollama/ollama:latest
    restart: always
    ports: ["11434:11434"]
    volumes: [ollama:/root/.ollama]
    deploy:
      resources:
        reservations:
          devices: [{driver: nvidia, count: 1, capabilities: [gpu]}]
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    restart: always
    ports: ["3000:8080"]
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
      - SEARXNG_QUERY_URL=http://searxng:8080/search?q=
    volumes: [open-webui:/app/backend/data]
    depends_on: [ollama, searxng]
  searxng:
    image: searxng/searxng:latest
    restart: always
    ports: ["8080:8080"]
    volumes: [./searxng:/etc/searxng]
    environment:
      - BASE_URL=http://localhost:8080/
volumes: {ollama: {}, open-webui: {}}
EOF
        elif [ "$CHOIX_AI_GPU" == "2" ]; then
            # === AMD ===
            usermod -aG render,video $REAL_USER
            # Sur Arch, ROCm peut demander des paquets specifiques, mais Docker gère via /dev/kfd
            
            cat <<EOF > "$INSTALL_DIR/docker-compose.yml"
services:
  ollama:
    image: ollama/ollama:latest
    restart: always
    ports: ["11434:11434"]
    devices:
      - "/dev/kfd:/dev/kfd"
      - "/dev/dri:/dev/dri"
    volumes: [ollama:/root/.ollama]
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    restart: always
    ports: ["3000:8080"]
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
      - SEARXNG_QUERY_URL=http://searxng:8080/search?q=
    volumes: [open-webui:/app/backend/data]
    depends_on: [ollama, searxng]
  searxng:
    image: searxng/searxng:latest
    restart: always
    ports: ["8080:8080"]
    volumes: [./searxng:/etc/searxng]
    environment:
      - BASE_URL=http://localhost:8080/
volumes: {ollama: {}, open-webui: {}}
EOF
        else
            # === CPU ONLY ===
            cat <<EOF > "$INSTALL_DIR/docker-compose.yml"
services:
  ollama:
    image: ollama/ollama:latest
    restart: always
    ports: ["11434:11434"]
    volumes: [ollama:/root/.ollama]
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    restart: always
    ports: ["3000:8080"]
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
      - SEARXNG_QUERY_URL=http://searxng:8080/search?q=
    volumes: [open-webui:/app/backend/data]
    depends_on: [ollama, searxng]
  searxng:
    image: searxng/searxng:latest
    restart: always
    ports: ["8080:8080"]
    volumes: [./searxng:/etc/searxng]
    environment:
      - BASE_URL=http://localhost:8080/
volumes: {ollama: {}, open-webui: {}}
EOF
        fi

        # Config SearXNG
        echo "use_default_settings: true" > "$INSTALL_DIR/searxng/settings.yml"
        echo "server: {secret_key: \"$(openssl rand -hex 16)\"}" >> "$INSTALL_DIR/searxng/settings.yml"
        echo "search: {formats: [html, json]}" >> "$INSTALL_DIR/searxng/settings.yml"

        chown -R $REAL_USER:docker "$INSTALL_DIR"
        
        # Lancement Docker Compose
        cd "$INSTALL_DIR"
        echo "[+] Lancement des conteneurs principaux..."
        docker compose up -d

        # AJOUT PERPLEXICA
        if [ "$INSTALL_PERPLEXICA" = true ]; then
            echo "[+] Installation de Perplexica (Port 7000)..."
            docker stop perplexica 2>/dev/null || true
            docker rm perplexica 2>/dev/null || true
            
            docker run -d \
              --name perplexica \
              --restart always \
              -p 7000:3000 \
              --add-host=host.docker.internal:host-gateway \
              -e SEARXNG_API_URL=http://host.docker.internal:8080 \
              -e OLLAMA_API_URL=http://host.docker.internal:11434 \
              -v perplexica-data:/home/perplexica/data \
              itzcrazykns1337/perplexica:slim-latest
        fi

        whiptail --msgbox "Installation Terminée !\n\nOpenWebUI: http://localhost:3000\nPerplexica: http://localhost:7000" 12 60
    fi
}

# --- 4. MENU PRINCIPAL ---

while true; do
    CHOIX=$(whiptail --title "CACHYOS ARCHITECT" --backtitle "$BACKTITLE" --menu "Menu Principal (Arch/CachyOS) :" 24 75 10 \
    "1 SYSTEME" "Mise à jour (Pacman -Syu)" \
    "2 GPU" "Pilotes Graphiques (Nvidia/AMD/Intel)" \
    "3 OPTIMISATION" "Laptop (TLP, Microcode, Thermald)" \
    "4 GAMING" "Steam, Gamemode, MangoHud" \
    "5 NAVIGATEURS" "Chrome(AUR), Zen(AUR), Firefox" \
    "6 SOCIAL" "Discord, Telegram" \
    "7 LOGICIELS" "VLC, OBS, VSCode(AUR)" \
    "8 AI STACK" "Docker + Ollama + WebUI + Perplexica" \
    "QUITTER" "Sortir du script" 3>&1 1>&2 2>&3)

    EXIT_STATUS=$?
    if [ $EXIT_STATUS -eq 0 ]; then
        case $CHOIX in
            "1 SYSTEME") module_system ;;
            "2 GPU") module_gpu ;;
            "3 OPTIMISATION") module_optimization ;;
            "4 GAMING") module_gaming ;;
            "5 NAVIGATEURS") module_browsers ;;
            "6 SOCIAL") module_social ;;
            "7 LOGICIELS") module_software ;;
            "8 AI STACK") module_ai_stack ;;
            "QUITTER") break ;;
        esac
    else
        break
    fi
done

clear
echo "Au revoir !"
