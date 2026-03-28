#!/bin/bash

# Define variables
URL="https://discord.com/api/download?platform=linux&format=tar.gz"
HOME_DIR=$(getent passwd $(id -u) | cut -d: -f6)
ARCHIVE_NAME="discord.tar.gz"
EXTRACT_DIR="$HOME_DIR"
DESKTOP_DIR="$HOME_DIR/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/discord.desktop"

# Create the extraction directory
mkdir -p "$EXTRACT_DIR"

# Create the applications directory if it doesn't exist
mkdir -p "$DESKTOP_DIR"

# Download Discord
echo "Downloading Discord for Linux..."
wget -O "$ARCHIVE_NAME" "$URL"

# Check if download was successful
if [ $? -ne 0 ]; then
    echo "Failed to download Discord. Please check your internet connection or the URL."
    exit 1
fi

# Extract Discord archive
echo "Extracting Discord archive..."
tar -xzvf "$ARCHIVE_NAME" -C "$EXTRACT_DIR"

# Check if extraction was successful
if [ $? -ne 0 ]; then
    echo "Failed to extract Discord archive. Please check if the file is corrupted."
    rm "$ARCHIVE_NAME"  # Clean up the downloaded file since extraction failed
    exit 1
fi

# Clean up the downloaded Discord archive
rm "$ARCHIVE_NAME"

# Create the Discord desktop entry file
echo "Creating Discord desktop entry..."
cat > "$DESKTOP_FILE" << 'EOF'
[Desktop Entry]
Name=Discord
Exec=/home/mrthp/Discord/Discord
Icon=/home/mrthp/Discord/discord.png
Type=Application
Categories=Network;InstantMessaging;
EOF

# Set proper permissions for the desktop file
chmod 644 "$DESKTOP_FILE"

# Make the Discord executable file executable
if [ -f "$HOME_DIR/Discord/Discord" ]; then
    chmod +x "$HOME_DIR/Discord/Discord"
    echo "Made Discord executable"
else
    echo "Warning: Discord executable not found at $HOME_DIR/Discord/Discord"
    echo "You may need to adjust the Exec path in $DESKTOP_FILE manually"
fi

echo "Discord has been successfully downloaded and extracted to $EXTRACT_DIR"
echo "Desktop entry has been created at $DESKTOP_FILE"
echo "Discord installation complete!"
