#!/bin/bash

# SSH2 Manager - Console SSH connection manager with dialog interface
# Author: SSH2 Manager Script
# Dependencies: dialog, ssh

# Configuration
SCRIPT_NAME="SSH2 Manager"
VERSION="1.0"
CONFIG_DIR="$HOME/.ssh2manager"
SERVERS_FILE="$CONFIG_DIR/servers.conf"
TEMP_FILE="/tmp/ssh2manager_temp.$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize configuration directory and file
init_config() {
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
    fi
    
    if [ ! -f "$SERVERS_FILE" ]; then
        touch "$SERVERS_FILE"
    fi
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v dialog >/dev/null 2>&1; then
        missing_deps+=("dialog")
    fi
    
    if ! command -v ssh >/dev/null 2>&1; then
        missing_deps+=("openssh-client")
    fi
    
    if ! command -v ssh-copy-id >/dev/null 2>&1; then
        missing_deps+=("ssh-copy-id")
    fi
    
    if ! command -v ssh-keyscan >/dev/null 2>&1; then
        missing_deps+=("ssh-keyscan")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}Missing dependencies: ${missing_deps[*]}${NC}"
        echo "Please install the missing packages and try again."
        exit 1
    fi
}

# Clean up temporary files
cleanup() {
    rm -f "$TEMP_FILE" "$TEMP_FILE.menu" "$TEMP_FILE.form"
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Load servers from configuration file
load_servers() {
    if [ -f "$SERVERS_FILE" ]; then
        cat "$SERVERS_FILE"
    fi
}

# Save server to configuration file
save_server() {
    local name="$1"
    local host="$2"
    local port="$3"
    local user="$4"
    local key="$5"
    local note="$6"
    
    # Remove existing entry with same name
    if [ -f "$SERVERS_FILE" ]; then
        grep -v "^$name|" "$SERVERS_FILE" > "$TEMP_FILE" || true
        mv "$TEMP_FILE" "$SERVERS_FILE"
    fi
    
    # Add new entry
    echo "$name|$host|$port|$user|$key|$note" >> "$SERVERS_FILE"
}

# Remove server from configuration file
remove_server() {
    local name="$1"
    
    if [ -f "$SERVERS_FILE" ]; then
        grep -v "^$name|" "$SERVERS_FILE" > "$TEMP_FILE" || true
        mv "$TEMP_FILE" "$SERVERS_FILE"
    fi
}

# Get server details by name
get_server() {
    local name="$1"
    
    if [ -f "$SERVERS_FILE" ]; then
        grep "^$name|" "$SERVERS_FILE" | head -n1
    fi
}

# Validate input fields
validate_input() {
    local name="$1"
    local host="$2"
    local port="$3"
    local user="$4"
    
    if [ -z "$name" ]; then
        dialog --msgbox "Server name cannot be empty!" 6 40
        return 1
    fi
    
    if [ -z "$host" ]; then
        dialog --msgbox "Hostname/IP cannot be empty!" 6 40
        return 1
    fi
    
    if [ -z "$port" ]; then
        port="22"
    elif ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        dialog --msgbox "Port must be a number between 1 and 65535!" 6 50
        return 1
    fi
    
    if [ -z "$user" ]; then
        dialog --msgbox "Username cannot be empty!" 6 40
        return 1
    fi
    
    return 0
}

# Add new server
add_server() {
    local form_data
    local name="" host="" port="22" user="" key="auto" note=""
    
    while true; do
        form_data=$(dialog --stdout --title "Add New Server" \
            --form "Enter server details:" 15 60 5 \
            "Name:" 1 1 "$name" 1 10 40 0 \
            "Host/IP:" 2 1 "$host" 2 10 40 0 \
            "Port:" 3 1 "$port" 3 10 40 0 \
            "Username:" 4 1 "$user" 4 10 40 0 \
            "Note:" 5 1 "$note" 5 10 40 0)
        
        if [ $? -ne 0 ]; then
            return
        fi
        
        # Parse form data
        name=$(echo "$form_data" | sed -n '1p')
        host=$(echo "$form_data" | sed -n '2p')
        port=$(echo "$form_data" | sed -n '3p')
        user=$(echo "$form_data" | sed -n '4p')
        note=$(echo "$form_data" | sed -n '5p')
        
        # Validate input
        if validate_input "$name" "$host" "$port" "$user"; then
            # Select SSH key
            key=$(select_ssh_key "$key")
            
            # Check if server name already exists
            if get_server "$name" >/dev/null; then
                dialog --yesno "Server '$name' already exists. Overwrite?" 6 50
                if [ $? -ne 0 ]; then
                    continue
                fi
            fi
            
            save_server "$name" "$host" "$port" "$user" "$key" "$note"
            dialog --msgbox "Server '$name' added successfully!" 6 40
            break
        fi
    done
}

# Edit existing server
edit_server() {
    # Get list of servers for selection
    local servers=()
    while IFS='|' read -r name host port user key note; do
        if [ -n "$name" ]; then
            servers+=("$name" "$host:$port ($user)")
        fi
    done < <(load_servers)
    
    if [ ${#servers[@]} -eq 0 ]; then
        dialog --msgbox "No servers configured!" 6 30
        return
    fi
    
    # Select server to edit
    local selected
    selected=$(dialog --stdout --title "Edit Server" \
        --menu "Select server to edit:" 15 60 8 "${servers[@]}")
    
    if [ $? -ne 0 ] || [ -z "$selected" ]; then
        return
    fi
    
    # Get current server details
    local server_data=$(get_server "$selected")
    if [ -z "$server_data" ]; then
        dialog --msgbox "Server not found!" 6 30
        return
    fi
    
    IFS='|' read -r name host port user key note <<< "$server_data"
    
    # Edit form
    local form_data
    while true; do
        form_data=$(dialog --stdout --title "Edit Server: $name" \
            --form "Edit server details:" 15 60 5 \
            "Name:" 1 1 "$name" 1 10 40 0 \
            "Host/IP:" 2 1 "$host" 2 10 40 0 \
            "Port:" 3 1 "$port" 3 10 40 0 \
            "Username:" 4 1 "$user" 4 10 40 0 \
            "Note:" 5 1 "$note" 5 10 40 0)
        
        if [ $? -ne 0 ]; then
            return
        fi
        
        # Parse form data
        local new_name=$(echo "$form_data" | sed -n '1p')
        local new_host=$(echo "$form_data" | sed -n '2p')
        local new_port=$(echo "$form_data" | sed -n '3p')
        local new_user=$(echo "$form_data" | sed -n '4p')
        local new_note=$(echo "$form_data" | sed -n '5p')
        
        # Validate input
        if validate_input "$new_name" "$new_host" "$new_port" "$new_user"; then
            # Select SSH key (keeping current selection as default)
            local new_key=$(select_ssh_key "$key")
            
            # If name changed, check if new name already exists
            if [ "$name" != "$new_name" ] && get_server "$new_name" >/dev/null; then
                dialog --msgbox "Server name '$new_name' already exists!" 6 50
                continue
            fi
            
            # Remove old entry if name changed
            if [ "$name" != "$new_name" ]; then
                remove_server "$name"
            fi
            
            save_server "$new_name" "$new_host" "$new_port" "$new_user" "$new_key" "$new_note"
            dialog --msgbox "Server updated successfully!" 6 40
            break
        fi
    done
}

# Remove server
remove_server_menu() {
    # Get list of servers for selection
    local servers=()
    while IFS='|' read -r name host port user key note; do
        if [ -n "$name" ]; then
            servers+=("$name" "$host:$port ($user)")
        fi
    done < <(load_servers)
    
    if [ ${#servers[@]} -eq 0 ]; then
        dialog --msgbox "No servers configured!" 6 30
        return
    fi
    
    # Select server to remove
    local selected
    selected=$(dialog --stdout --title "Remove Server" \
        --menu "Select server to remove:" 15 60 8 "${servers[@]}")
    
    if [ $? -ne 0 ] || [ -z "$selected" ]; then
        return
    fi
    
    # Confirm removal
    dialog --yesno "Are you sure you want to remove server '$selected'?" 6 50
    if [ $? -eq 0 ]; then
        remove_server "$selected"
        dialog --msgbox "Server '$selected' removed successfully!" 6 40
    fi
}

# List all servers
list_servers() {
    local servers_info=""
    local count=0
    
    while IFS='|' read -r name host port user key note; do
        if [ -n "$name" ]; then
            count=$((count + 1))
            servers_info="${servers_info}Name: $name\n"
            servers_info="${servers_info}Host: $host:$port\n"
            servers_info="${servers_info}User: $user\n"
            
            # Display SSH key information
            case "$key" in
                "auto"|"")
                    local default_key=$(find_default_ssh_key)
                    if [ -n "$default_key" ]; then
                        servers_info="${servers_info}Key:  auto (using $default_key)\n"
                    else
                        servers_info="${servers_info}Key:  auto (no default key found)\n"
                    fi
                    ;;
                "none")
                    servers_info="${servers_info}Auth: password authentication\n"
                    ;;
                *)
                    if [ -f "$key" ]; then
                        servers_info="${servers_info}Key:  $key\n"
                    else
                        servers_info="${servers_info}Key:  $key (file not found)\n"
                    fi
                    ;;
            esac
            
            if [ -n "$note" ]; then
                servers_info="${servers_info}Note: $note\n"
            fi
            servers_info="${servers_info}\n"
        fi
    done < <(load_servers)
    
    if [ $count -eq 0 ]; then
        dialog --msgbox "No servers configured!" 6 30
    else
        dialog --msgbox "Configured Servers ($count):\n\n$servers_info" 20 70
    fi
}

# Get available SSH keys
get_ssh_keys() {
    local keys=()
    local ssh_dir="$HOME/.ssh"
    
    # Add "auto" option for default key selection
    keys+=("auto" "Use default SSH key (automatic)")
    
    # Common SSH key names
    local key_types=("id_rsa" "id_ed25519" "id_ecdsa" "id_dsa")
    
    for key_type in "${key_types[@]}"; do
        if [ -f "$ssh_dir/$key_type" ]; then
            keys+=("$ssh_dir/$key_type" "$key_type (found)")
        fi
    done
    
    # Add custom option
    keys+=("custom" "Browse for custom key file")
    keys+=("none" "No SSH key (password auth)")
    
    echo "${keys[@]}"
}

# Select SSH key for server configuration
select_ssh_key() {
    local current_key="$1"
    local keys=($(get_ssh_keys))
    
    # Set default selection
    local default_tag="auto"
    if [ -n "$current_key" ]; then
        if [ "$current_key" = "auto" ]; then
            default_tag="auto"
        elif [ "$current_key" = "none" ]; then
            default_tag="none"
        elif [ -f "$current_key" ]; then
            default_tag="$current_key"
        else
            default_tag="custom"
        fi
    fi
    
    local selected
    selected=$(dialog --stdout --title "Select SSH Key" \
        --default-item "$default_tag" \
        --menu "Choose SSH key authentication method:" 15 60 8 "${keys[@]}")
    
    if [ $? -ne 0 ]; then
        echo "$current_key"  # Return original if cancelled
        return
    fi
    
    case "$selected" in
        "custom")
            local custom_key
            custom_key=$(dialog --stdout --title "Custom SSH Key" \
                --fselect "$HOME/.ssh/" 14 48)
            if [ $? -eq 0 ] && [ -f "$custom_key" ]; then
                echo "$custom_key"
            else
                echo "$current_key"
            fi
            ;;
        *)
            echo "$selected"
            ;;
    esac
}

# Find default SSH key
find_default_ssh_key() {
    local ssh_dir="$HOME/.ssh"
    local key_types=("id_ed25519" "id_rsa" "id_ecdsa" "id_dsa")
    
    for key_type in "${key_types[@]}"; do
        if [ -f "$ssh_dir/$key_type" ]; then
            echo "$ssh_dir/$key_type"
            return
        fi
    done
    
    # No default key found
    echo ""
}

# Copy SSH key to remote server
copy_ssh_key() {
    # Get list of servers for selection
    local servers=()
    while IFS='|' read -r name host port user key note; do
        if [ -n "$name" ]; then
            local desc="$host:$port ($user)"
            if [ -n "$note" ]; then
                desc="$desc - $note"
            fi
            servers+=("$name" "$desc")
        fi
    done < <(load_servers)
    
    if [ ${#servers[@]} -eq 0 ]; then
        dialog --msgbox "No servers configured!" 6 30
        return
    fi
    
    # Select server to copy key to
    local selected
    selected=$(dialog --stdout --title "Copy SSH Key to Server" \
        --menu "Select server to copy SSH key to:" 15 70 8 "${servers[@]}")
    
    if [ $? -ne 0 ] || [ -z "$selected" ]; then
        return
    fi
    
    # Get server details
    local server_data=$(get_server "$selected")
    if [ -z "$server_data" ]; then
        dialog --msgbox "Server not found!" 6 30
        return
    fi
    
    IFS='|' read -r name host port user key note <<< "$server_data"
    
    # Determine which key to copy
    local key_to_copy=""
    local key_display=""
    
    case "$key" in
        "auto"|"")
            key_to_copy=$(find_default_ssh_key)
            if [ -z "$key_to_copy" ]; then
                dialog --msgbox "No default SSH key found!\n\nPlease generate an SSH key first using:\nssh-keygen -t ed25519" 8 50
                return
            fi
            key_display="default key ($key_to_copy)"
            ;;
        "none")
            # For password auth, still try to copy default key
            key_to_copy=$(find_default_ssh_key)
            if [ -z "$key_to_copy" ]; then
                dialog --msgbox "No SSH key found to copy!\n\nPlease generate an SSH key first using:\nssh-keygen -t ed25519" 8 50
                return
            fi
            key_display="default key ($key_to_copy)"
            ;;
        *)
            if [ -f "$key" ]; then
                key_to_copy="$key"
                key_display="$key"
            else
                dialog --msgbox "SSH key file not found: $key\n\nTrying default key instead..." 8 50
                key_to_copy=$(find_default_ssh_key)
                if [ -z "$key_to_copy" ]; then
                    dialog --msgbox "No SSH key available to copy!" 6 40
                    return
                fi
                key_display="default key ($key_to_copy)"
            fi
            ;;
    esac
    
    # Confirm key copy operation
    dialog --yesno "Copy SSH key to server?\n\nServer: $name ($host:$port)\nUser: $user\nKey: $key_display\n\nThis will enable passwordless login." 12 60
    if [ $? -ne 0 ]; then
        return
    fi
    
    # Build ssh-copy-id command
    local copy_args=()
    copy_args+=("-i" "$key_to_copy")
    copy_args+=("-p" "$port")
    copy_args+=("-o" "StrictHostKeyChecking=no")  # Auto-accept fingerprint
    copy_args+=("-o" "UserKnownHostsFile=/dev/null")  # Don't save to known_hosts during copy
    copy_args+=("$user@$host")
    
    # Clear screen and show copy operation
    clear
    echo -e "${GREEN}Copying SSH key to $name ($host:$port)...${NC}"
    echo -e "${BLUE}User: $user${NC}"
    echo -e "${BLUE}Key: $key_display${NC}"
    echo -e "${YELLOW}Note: Host fingerprint will be automatically accepted${NC}"
    echo ""
    
    # Execute ssh-copy-id
    if ssh-copy-id "${copy_args[@]}"; then
        echo ""
        echo -e "${GREEN}SSH key copied successfully!${NC}"
        echo -e "${GREEN}You can now connect to this server without a password.${NC}"
        
        # Update known_hosts with proper fingerprint
        echo ""
        echo -e "${BLUE}Adding server to known_hosts...${NC}"
        ssh-keyscan -p "$port" "$host" >> "$HOME/.ssh/known_hosts" 2>/dev/null
        
        # Ask if user wants to test the connection
        echo ""
        echo -e "${YELLOW}Press 't' to test connection, or any other key to continue...${NC}"
        read -n 1 test_key
        
        if [ "$test_key" = "t" ] || [ "$test_key" = "T" ]; then
            echo ""
            echo -e "${BLUE}Testing SSH connection...${NC}"
            echo ""
            
            # Test connection
            local ssh_test_args=()
            ssh_test_args+=("-p" "$port")
            ssh_test_args+=("-i" "$key_to_copy")
            ssh_test_args+=("-o" "BatchMode=yes")  # Non-interactive
            ssh_test_args+=("-o" "ConnectTimeout=10")
            ssh_test_args+=("$user@$host")
            ssh_test_args+=("echo 'SSH key authentication successful!'")
            
            if ssh "${ssh_test_args[@]}"; then
                echo -e "${GREEN}Connection test successful!${NC}"
            else
                echo -e "${RED}Connection test failed. You may need to enter password manually.${NC}"
            fi
        fi
    else
        echo ""
        echo -e "${RED}Failed to copy SSH key!${NC}"
        echo -e "${YELLOW}This might be due to:${NC}"
        echo -e "${YELLOW}- Wrong username or password${NC}"
        echo -e "${YELLOW}- Server doesn't accept password authentication${NC}"
        echo -e "${YELLOW}- Network connectivity issues${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Press any key to return to menu...${NC}"
    read -n 1
}

# Connect to server
connect_server() {
    # Get list of servers for selection
    local servers=()
    while IFS='|' read -r name host port user key note; do
        if [ -n "$name" ]; then
            local desc="$host:$port ($user)"
            if [ -n "$note" ]; then
                desc="$desc - $note"
            fi
            servers+=("$name" "$desc")
        fi
    done < <(load_servers)
    
    if [ ${#servers[@]} -eq 0 ]; then
        dialog --msgbox "No servers configured!" 6 30
        return
    fi
    
    # Select server to connect
    local selected
    selected=$(dialog --stdout --title "Connect to Server" \
        --menu "Select server to connect:" 15 70 8 "${servers[@]}")
    
    if [ $? -ne 0 ] || [ -z "$selected" ]; then
        return
    fi
    
    # Get server details
    local server_data=$(get_server "$selected")
    if [ -z "$server_data" ]; then
        dialog --msgbox "Server not found!" 6 30
        return
    fi
    
    IFS='|' read -r name host port user key note <<< "$server_data"
    
    # Build SSH command array for proper argument handling
    local ssh_args=()
    ssh_args+=("-p" "$port")
    
    # Handle SSH key selection
    local key_to_use=""
    case "$key" in
        "auto"|"")
            key_to_use=$(find_default_ssh_key)
            if [ -n "$key_to_use" ]; then
                ssh_args+=("-i" "$key_to_use")
                echo -e "${BLUE}Using default SSH key: $key_to_use${NC}"
            else
                echo -e "${YELLOW}No default SSH key found, using password authentication${NC}"
            fi
            ;;
        "none")
            echo -e "${YELLOW}Using password authentication${NC}"
            ;;
        *)
            if [ -f "$key" ]; then
                ssh_args+=("-i" "$key")
                key_to_use="$key"
                echo -e "${BLUE}Using SSH key: $key${NC}"
            else
                echo -e "${RED}SSH key file not found: $key${NC}"
                echo -e "${YELLOW}Falling back to password authentication${NC}"
            fi
            ;;
    esac
    
    # Add StrictHostKeyChecking=accept-new for automatic fingerprint acceptance
    ssh_args+=("-o" "StrictHostKeyChecking=accept-new")
    ssh_args+=("$user@$host")
    
    # Clear screen and connect
    clear
    echo -e "${GREEN}Connecting to $name ($host:$port)...${NC}"
    echo -e "${BLUE}User: $user${NC}"
    if [ -n "$key_to_use" ]; then
        echo -e "${BLUE}SSH Key: $key_to_use${NC}"
    fi
    if [ -n "$note" ]; then
        echo -e "${BLUE}Note: $note${NC}"
    fi
    echo ""
    
    # Execute SSH connection
    ssh "${ssh_args[@]}"
    
    echo ""
    echo -e "${YELLOW}Connection closed. Press any key to return to menu...${NC}"
    read -n 1
}

# Show about dialog
show_about() {
    dialog --msgbox "$SCRIPT_NAME v$VERSION\n\nA console-based SSH connection manager\nwith dialog interface.\n\nFeatures:\n- Add/Edit/Remove servers\n- Store connection details\n- Add notes for servers\n- Quick connection\n- Copy SSH keys to servers\n- Auto-accept host fingerprints\n\nConfiguration stored in:\n$CONFIG_DIR" 18 50
}

# Main menu
main_menu() {
    while true; do
        local choice
        choice=$(dialog --stdout --title "$SCRIPT_NAME v$VERSION" \
            --menu "Choose an option:" 16 50 9 \
            "1" "Connect to Server" \
            "2" "Add New Server" \
            "3" "Edit Server" \
            "4" "Remove Server" \
            "5" "Copy SSH Key to Server" \
            "6" "List All Servers" \
            "7" "About" \
            "8" "Exit")
        
        case $? in
            0)
                case $choice in
                    1) connect_server ;;
                    2) add_server ;;
                    3) edit_server ;;
                    4) remove_server_menu ;;
                    5) copy_ssh_key ;;
                    6) list_servers ;;
                    7) show_about ;;
                    8) break ;;
                esac
                ;;
            1|255)
                break
                ;;
        esac
    done
}

# Main execution
main() {
    # Check dependencies
    check_dependencies
    
    # Initialize configuration
    init_config
    
    # Show main menu
    main_menu
    
    # Clear screen on exit
    clear
    echo -e "${GREEN}Thank you for using $SCRIPT_NAME!${NC}"
}

# Run main function
main "$@"
