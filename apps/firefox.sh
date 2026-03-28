#!/bin/bash

# Set variables
FIREFOX_URL="https://download.mozilla.org/?product=firefox-latest&os=linux64&lang=en-CA"
DOWNLOAD_DIR="$HOME"
INSTALL_DIR="$HOME/firefox"
DESKTOP_FILE="$HOME/.local/share/applications/firefox.desktop"

# Create temporary directory for download
TEMP_DIR=$(mktemp -d)

# Download Firefox
echo "Downloading Firefox..."
wget -O "$TEMP_DIR/firefox.tar.xz" "$FIREFOX_URL"

# Check if download was successful
if [ $? -ne 0 ]; then
    echo "Download failed!"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Remove existing Firefox installation if it exists
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
fi

# Extract the archive
echo "Extracting Firefox..."
tar -xJf "$TEMP_DIR/firefox.tar.xz" -C "$DOWNLOAD_DIR"

# Clean up temporary directory
rm -rf "$TEMP_DIR"

# Create .desktop file
echo "Creating desktop entry..."
mkdir -p "$HOME/.local/share/applications"

cat > "$DESKTOP_FILE" << 'EOL'
[Desktop Entry]
Version=1.0
Name=Firefox
Comment=Web Browser
Exec=/home/mrthp/firefox/firefox %u
Terminal=false
Type=Application
Icon=/home/mrthp/firefox/browser/chrome/icons/default/default128.png
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/vnd.mozilla.xul+xml;x-scheme-handler/http;x-scheme-handler/https;
StartupNotify=true

EOL

# Make the desktop file executable
chmod +x "$DESKTOP_FILE"

echo "Firefox has been installed to $INSTALL_DIR"
echo "Desktop entry created at $DESKTOP_FILE"
echo "You can now launch Firefox from your applications menu!"
