#!/bin/bash

# WiFi Manager - Ncurses based WiFi connection tool
# For Debian Trixie Linux

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Check and install dependencies if needed
check_dependencies() {
    local deps=("nmcli" "dialog" "iw" "wpa_supplicant")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo "Missing dependencies: ${missing[*]}"
        echo "Installing required packages..."
        apt-get update
        apt-get install -y network-manager dialog iw wpasupplicant
    fi
}

# Function to scan WiFi networks
scan_wifi() {
    local temp_file=$(mktemp)
    
    # Show scanning message
    dialog --infobox "Scanning for WiFi networks...\nPlease wait." 5 40
    
    # Scan networks using nmcli
    nmcli dev wifi list --rescan yes | tail -n +2 > "$temp_file"
    
    if [ ! -s "$temp_file" ]; then
        dialog --msgbox "No WiFi networks found or WiFi adapter not available." 6 50
        rm -f "$temp_file"
        return 1
    fi
    
    # Format networks for dialog menu
    local menu_items=()
    local i=1
    
    while IFS= read -r line; do
        # Parse nmcli output
        local in_use=$(echo "$line" | awk '{print $1}')
        local ssid=$(echo "$line" | awk '{$1=""; print $0}' | awk '{print $1}')
        local signal=$(echo "$line" | awk '{print $8}')
        local security=$(echo "$line" | awk '{print $NF}')
        
        # Skip empty SSIDs
        if [ -z "$ssid" ] || [ "$ssid" = "--" ]; then
            continue
        fi
        
        # Format menu item
        local status=""
        if [ "$in_use" = "*" ]; then
            status="[CONNECTED] "
        fi
        
        local display_name="${status}${ssid} (Signal: ${signal}%, Security: ${security})"
        menu_items+=("$i" "$display_name")
        ((i++))
        
        # Store network info for later use
        echo "$i:$ssid:$security:$signal" >> /tmp/wifi_networks.tmp
    done < "$temp_file"
    
    rm -f "$temp_file"
    
    if [ ${#menu_items[@]} -eq 0 ]; then
        dialog --msgbox "No WiFi networks found." 5 40
        return 1
    fi
    
    # Display network selection menu
    local choice
    choice=$(dialog --clear --title "WiFi Networks" \
        --menu "Select a network to connect:" 20 70 15 \
        "${menu_items[@]}" \
        2>&1 >/dev/tty)
    
    if [ -n "$choice" ]; then
        # Get network details
        local network_info=$(grep "^$choice:" /tmp/wifi_networks.tmp)
        local ssid=$(echo "$network_info" | cut -d':' -f2)
        local security=$(echo "$network_info" | cut -d':' -f3)
        
        connect_to_wifi "$ssid" "$security"
    fi
    
    rm -f /tmp/wifi_networks.tmp
}

# Function to connect to WiFi
connect_to_wifi() {
    local ssid="$1"
    local security="$2"
    local password=""
    
    # Check if already connected
    if nmcli -t -f NAME con show --active | grep -q "$ssid"; then
        dialog --msgbox "Already connected to '$ssid'" 6 40
        return 0
    fi
    
    # Handle different security types
    case "$security" in
        "--")
            # Open network - no password needed
            dialog --infobox "Connecting to open network '$ssid'..." 5 40
            nmcli dev wifi connect "$ssid" > /tmp/wifi_connect.log 2>&1
            ;;
        *)
            # Secured network - ask for password
            password=$(dialog --clear --title "WiFi Password" \
                --insecure --passwordbox "Enter password for '$ssid':" 8 50 \
                2>&1 >/dev/tty)
            
            if [ -n "$password" ]; then
                dialog --infobox "Connecting to '$ssid'..." 5 40
                nmcli dev wifi connect "$ssid" password "$password" > /tmp/wifi_connect.log 2>&1
            else
                dialog --msgbox "Connection cancelled." 5 40
                return 1
            fi
            ;;
    esac
    
    # Check connection result
    if [ $? -eq 0 ]; then
        dialog --msgbox "Successfully connected to '$ssid'!" 6 40
    else
        local error_msg=$(cat /tmp/wifi_connect.log)
        dialog --msgbox "Failed to connect to '$ssid'.\n\nError: $error_msg" 10 50
    fi
}

# Function to show current connection
show_current() {
    local current=$(nmcli -t -f TYPE,NAME con show --active | grep "802-11-wireless" | cut -d':' -f2)
    
    if [ -n "$current" ]; then
        local signal=$(nmcli -t -f SSID,SIGNAL dev wifi list | grep "$current" | cut -d':' -f2)
        dialog --msgbox "Currently connected to:\n\nSSID: $current\nSignal: ${signal}%" 8 50
    else
        dialog --msgbox "Not connected to any WiFi network." 6 50
    fi
}

# Function to disconnect from WiFi
disconnect_wifi() {
    local current=$(nmcli -t -f TYPE,NAME con show --active | grep "802-11-wireless" | cut -d':' -f2)
    
    if [ -n "$current" ]; then
        dialog --yesno "Disconnect from '$current'?" 6 40
        if [ $? -eq 0 ]; then
            nmcli dev disconnect wlan0 > /dev/null 2>&1
            dialog --msgbox "Disconnected from '$current'." 6 40
        fi
    else
        dialog --msgbox "Not connected to any WiFi network." 6 50
    fi
}

# Function to show saved networks
show_saved() {
    local temp_file=$(mktemp)
    
    nmcli -t -f NAME,TYPE con show | grep ":802-11-wireless" | cut -d':' -f1 > "$temp_file"
    
    if [ -s "$temp_file" ]; then
        local networks=$(cat "$temp_file" | nl -w2 -s'. ')
        dialog --msgbox "Saved WiFi networks:\n\n$networks" 15 50
    else
        dialog --msgbox "No saved WiFi networks found." 6 50
    fi
    
    rm -f "$temp_file"
}

# Function to turn WiFi on/off
toggle_wifi() {
    local state=$(nmcli radio wifi)
    
    if [ "$state" = "enabled" ]; then
        dialog --yesno "Disable WiFi?" 5 40
        if [ $? -eq 0 ]; then
            nmcli radio wifi off
            dialog --msgbox "WiFi disabled." 5 40
        fi
    else
        dialog --yesno "Enable WiFi?" 5 40
        if [ $? -eq 0 ]; then
            nmcli radio wifi on
            dialog --msgbox "WiFi enabled." 5 40
        fi
    fi
}

# Function to get WiFi interface status
get_wifi_status() {
    local interfaces=$(iw dev 2>/dev/null | grep Interface | awk '{print $2}')
    
    if [ -n "$interfaces" ]; then
        local wifi_state=$(nmcli radio wifi)
        local current_con=$(nmcli -t -f TYPE,NAME con show --active | grep "802-11-wireless" | cut -d':' -f2)
        
        local status="WiFi Interfaces: $interfaces\n"
        status+="WiFi Radio: $wifi_state\n"
        
        if [ -n "$current_con" ]; then
            status+="Current Connection: $current_con"
        else
            status+="Current Connection: None"
        fi
        
        dialog --msgbox "$status" 10 50
    else
        dialog --msgbox "No WiFi interfaces found!" 6 40
    fi
}

# Main menu function
main_menu() {
    while true; do
        local choice
        choice=$(dialog --clear --title "WiFi Manager" \
            --menu "Choose an option:" 18 60 10 \
            1 "Scan and Connect to WiFi" \
            2 "Show Current Connection" \
            3 "Disconnect from WiFi" \
            4 "Show Saved Networks" \
            5 "Toggle WiFi (On/Off)" \
            6 "Show WiFi Status" \
            7 "Exit" \
            2>&1 >/dev/tty)
        
        case $choice in
            1) scan_wifi ;;
            2) show_current ;;
            3) disconnect_wifi ;;
            4) show_saved ;;
            5) toggle_wifi ;;
            6) get_wifi_status ;;
            7) 
                clear
                echo "Goodbye!"
                exit 0
                ;;
            *) 
                clear
                exit 0
                ;;
        esac
    done
}

# Main execution
clear
echo "Starting WiFi Manager..."
echo "Checking dependencies..."

# Check and install dependencies
check_dependencies

# Make sure NetworkManager is running
systemctl is-active --quiet NetworkManager || systemctl start NetworkManager

# Clear any temporary files
rm -f /tmp/wifi_networks.tmp 2>/dev/null

# Start the main menu
main_menu