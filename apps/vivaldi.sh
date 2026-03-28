#!/usr/bin/env bash
# ------------------------------------------------------------
# install_vivaldi.sh – Installe la dernière version stable de Vivaldi
# ------------------------------------------------------------

set -euo pipefail   # Arrêt immédiat en cas d’erreur

# ----------- Variables ----------
# Répertoire temporaire où le .deb sera téléchargé
TMP_DIR="/tmp/vivaldi_install"
DEB_FILE="${TMP_DIR}/vivaldi.deb"

# URL qui pointe toujours vers la dernière version stable (64‑bit)
VIVALDI_URL="https://downloads.vivaldi.com/stable/vivaldi-stable_amd64.deb"

# Répertoire du raccourci .desktop (pour que le lanceur apparaisse dans le menu)
DESKTOP_DIR="${HOME}/.local/share/applications"
DESKTOP_FILE="${DESKTOP_DIR}/vivaldi.desktop"

# ----------- Préparation ----------
echo "Création du répertoire temporaire…"
mkdir -p "${TMP_DIR}"
mkdir -p "${DESKTOP_DIR}"

# ----------- Téléchargement ----------
echo "Téléchargement du dernier .deb de Vivaldi…"
wget -q --show-progress -O "${DEB_FILE}" "${VIVALDI_URL}"

# Vérifier que le fichier a bien été récupéré
if [[ ! -s "${DEB_FILE}" ]]; then
    echo "❌ Erreur : le fichier .deb n’a pas été téléchargé."
    exit 1
fi

# ----------- Installation ----------
echo "Installation du paquet .deb (demande sudo)…"
sudo dpkg -i "${DEB_FILE}" || {
    echo "⚠️ dpkg a rencontré des dépendances manquantes – résolution…"
    sudo apt-get install -f -y
    sudo dpkg -i "${DEB_FILE}"
}

# ----------- Création du lanceur ----------
cat > "${DESKTOP_FILE}" <<EOF
[Desktop Entry]
Name=Vivaldi
Comment=Navigateur web rapide et sécurisé
Exec=/opt/vivaldi/vivaldi %U
Icon=vivaldi
Terminal=false
Type=Application
Categories=Network;WebBrowser;
StartupNotify=true
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
EOF

chmod 644 "${DESKTOP_FILE}"
echo "🔗 Raccourci créé : ${DESKTOP_FILE}"

# ----------- Nettoyage ----------
echo "Suppression du répertoire temporaire…"
rm -rf "${TMP_DIR}"

echo "✅ Vivaldi a été installé avec succès !"
echo "Lance-le depuis le menu ou en tapant « vivaldi » dans un terminal."
