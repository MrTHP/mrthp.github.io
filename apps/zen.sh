#!/bin/bash

# Set variables
ZEN_URL="https://github.com/zen-browser/desktop/releases/latest/download/zen.linux-x86_64.tar.xz"
DOWNLOAD_DIR="$HOME"
INSTALL_DIR="$HOME/zen-browser"
DESKTOP_FILE="$HOME/.local/share/applications/zen-browser.desktop"

# Create temporary directory for download
TEMP_DIR=$(mktemp -d)

# Download Zen Browser
echo "Downloading Zen Browser..."
wget -O "$TEMP_DIR/zen.tar.xz" "$ZEN_URL"

# Check if download was successful
if [ $? -ne 0 ]; then
    echo "Download failed!"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Remove existing Zen Browser installation if it exists
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
fi

# Extract the archive
echo "Extracting Zen Browser..."
tar -xJf "$TEMP_DIR/zen.tar.xz" -C "$DOWNLOAD_DIR"

# Rename the extracted folder to zen-browser (Zen extracts as 'zen' by default)
mv "$DOWNLOAD_DIR/zen" "$INSTALL_DIR"

# Clean up temporary directory
rm -rf "$TEMP_DIR"

# Create .desktop file
echo "Creating desktop entry..."
mkdir -p "$HOME/.local/share/applications"

cat > "$DESKTOP_FILE" << 'EOL'
[Desktop Entry]
Version=1.0
Name=Zen Browser
Comment=Experience tranquillity while browsing the web
Exec=/home/mrthp/zen-browser/zen %u
Terminal=false
Type=Application
Icon=/home/mrthp/zen-browser/browser/chrome/icons/default/default128.png
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/vnd.mozilla.xul+xml;x-scheme-handler/http;x-scheme-handler/https;
StartupNotify=true
EOL

# Replace '/home/user' with the actual $HOME path in the desktop file
sed -i "s|/home/user|$HOME|g" "$DESKTOP_FILE"

# Make the desktop file executable
chmod +x "$DESKTOP_FILE"

echo "Zen Browser has been installed to $INSTALL_DIR"
echo "Desktop entry created at $DESKTOP_FILE"
echo "You can now launch Zen Browser from your applications menu!"
