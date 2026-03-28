#!/bin/bash

# Define variables
TELEGRAM_URL="https://telegram.org/dl/desktop/linux"
HOME_DIR=$(getent passwd $(id -u) | cut -d: -f6)
TELEGRAM_ARCHIVE="telegram.tar.xz"
EXTRACT_DIR="$HOME_DIR"
DESKTOP_DIR="$HOME_DIR/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/telegram.desktop"

# Create the extraction directory
mkdir -p "$EXTRACT_DIR"

# Create the applications directory if it doesn't exist
mkdir -p "$DESKTOP_DIR"

# Download Telegram
echo "Downloading Telegram for Linux..."
wget -O "$TELEGRAM_ARCHIVE" "$TELEGRAM_URL"

# Check if Telegram download was successful
if [ $? -ne 0 ]; then
    echo "Failed to download Telegram. Please check your internet connection or the URL."
    exit 1
fi

# Extract Telegram archive
echo "Extracting Telegram archive..."
tar -xJvf "$TELEGRAM_ARCHIVE" -C "$EXTRACT_DIR"

# Check if Telegram extraction was successful
if [ $? -ne 0 ]; then
    echo "Failed to extract Telegram archive. Please check if the file is corrupted."
    rm "$TELEGRAM_ARCHIVE"  # Clean up the downloaded file since extraction failed
    exit 1
fi

# Clean up the downloaded Telegram archive
rm "$TELEGRAM_ARCHIVE"

# Create the Telegram desktop entry file
echo "Creating Telegram desktop entry..."
cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Name=Telegram
Exec=$HOME_DIR/Telegram/Telegram
Icon=$HOME_DIR/Telegram/Telegram.png
Type=Application
Categories=Network;InstantMessaging;
EOF

# Set proper permissions for the desktop file
chmod 644 "$DESKTOP_FILE"

# Make Telegram executable
if [ -f "$HOME_DIR/Telegram/Telegram" ]; then
    chmod +x "$HOME_DIR/Telegram/Telegram"
    echo "Made Telegram executable"
else
    echo "Warning: Telegram executable not found at $HOME_DIR/Telegram/Telegram"
    echo "You may need to adjust the Exec path in $DESKTOP_FILE manually"
fi

echo "Telegram has been successfully downloaded and extracted to $EXTRACT_DIR"
echo "Desktop entry has been created at $DESKTOP_FILE"
echo "Telegram installation complete!"
