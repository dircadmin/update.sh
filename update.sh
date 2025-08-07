#!/bin/bash

# script by MacAdmin MSP, Stefan Oberle. 
# macOS XProtect and Safari Updater
# This script checks for macOS software updates and installs
# XProtect and/or Safari in the background.

# 

# update.sh help
show_usage() {
    echo "Usage: $0 [-x] [-s] [-f] [-h]"
    echo "Options:"
    echo "  -x    Install updates containing XProtect in the label"
    echo "  -s    Install updates containing Safari in the label"
    echo "  -f    Force Safari updates even if Safari is currently running"
    echo "  -h    Display this help message"
    exit 1
}

# Initialize flags
install_xprotect=false
install_safari=false
force_safari_update=false

# options
while getopts "xsfh" opt; do
    case ${opt} in
        x)
            install_xprotect=true
            ;;
        s)
            install_safari=true
            ;;
        f)
            force_safari_update=true
            ;;
        h)
            show_usage
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            show_usage
            ;;
    esac
done

# Check if Safari is running
is_safari_running() {
    # Check for Safari processes using multiple methods for better detection
    local safari_processes=$(pgrep -f "Safari" 2>/dev/null)
    local safari_bundle_processes=$(pgrep -f "com.apple.Safari" 2>/dev/null)
    
    if [[ -n "$safari_processes" || -n "$safari_bundle_processes" ]]; then
        echo "Safari processes detected:"
        if [[ -n "$safari_processes" ]]; then
            ps -p $safari_processes -o pid,comm 2>/dev/null | tail -n +2 | while read pid comm; do
                echo "  PID: $pid, Command: $comm"
            done
        fi
        if [[ -n "$safari_bundle_processes" ]]; then
            ps -p $safari_bundle_processes -o pid,comm 2>/dev/null | tail -n +2 | while read pid comm; do
                echo "  PID: $pid, Command: $comm"
            done
        fi
        return 0  # Safari is running
    else
        return 1  # Safari is not running
    fi
}

# Check if at least one option was provided
if [[ "$install_xprotect" == false && "$install_safari" == false ]]; then
    # If no options provided, default to both XProtect and Safari updates
    echo "Updating Safari and XProtect"
    install_xprotect=true
    install_safari=true
fi

echo "Checking for available software updates..."
# Run softwareupdate to list available updates and include config data
update_list=$(softwareupdate -l --include-config-data 2>&1)

# Check if the command was successful
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to check for software updates"
    echo "$update_list"
    exit 1
fi

# Extract labels of available updates
# Use grep to find lines with "Label:" and extract the label values - supporting both leading spaces and asterisk
labels=$(echo "$update_list" | grep -i "^[* ]*Label:" | sed 's/^[* ]*Label: //')

# Check if any updates were found
if [[ -z "$labels" ]]; then
    echo "No software updates are available at this time."
    exit 0
fi

echo "Available updates:"
echo "$labels"

# Filter labels based on command line options
xprotect_updates=()
safari_updates=()
mrtconfigdata_updates=()

while IFS= read -r label; do
    if [[ "$install_xprotect" == true && "$label" == *"XProtect"* ]]; then
        xprotect_updates+=("$label")
        echo "Found XProtect update: $label"
    fi
    
    if [[ "$install_xprotect" == true && "$label" == *"MRTConfigData"* ]]; then
        mrtconfigdata_updates+=("$label")
        echo "Found MRTConfigData update: $label"
    fi
    
    if [[ "$install_safari" == true && "$label" == *"Safari"* ]]; then
        safari_updates+=("$label")
        echo "Found Safari update: $label"
    fi
done <<< "$labels"

# Prepare the install command
install_cmd="softwareupdate -i --include-config-data"
updates_to_install=()

# Add XProtect and MRTConfigData updates to installation list
if [[ "$install_xprotect" == true && (${#xprotect_updates[@]} -gt 0 || ${#mrtconfigdata_updates[@]} -gt 0) ]]; then
    if [[ ${#xprotect_updates[@]} -gt 0 ]]; then
        echo "XProtect updates to install:"
        for update in "${xprotect_updates[@]}"; do
            echo "  - $update"
            updates_to_install+=("$update")
        done
    fi
    
    if [[ ${#mrtconfigdata_updates[@]} -gt 0 ]]; then
        echo "MRTConfigData updates to install:"
        for update in "${mrtconfigdata_updates[@]}"; do
            echo "  - $update"
            updates_to_install+=("$update")
        done
    fi
fi

# Add Safari updates to installation list if Safari is not running or forced update
if [[ "$install_safari" == true && ${#safari_updates[@]} -gt 0 ]]; then
    # Check if Safari is running and not forced
    if is_safari_running && [[ "$force_safari_update" == false ]]; then
        echo "Safari is currently running. Safari updates will be skipped."
        echo "Use the -f option to force Safari updates even when Safari is running."
    else
        # Safari is either not running OR force flag is set
        if is_safari_running && [[ "$force_safari_update" == true ]]; then
            echo "Safari is running but updates will be installed due to -f flag."
        elif ! is_safari_running; then
            echo "Safari is not running. Safari updates will be installed."
        fi
        
        echo "Safari updates to install:"
        for update in "${safari_updates[@]}"; do
            echo "  - $update"
            updates_to_install+=("$update")
        done
    fi
fi

# Check if there are any updates to install
if [[ ${#updates_to_install[@]} -eq 0 ]]; then
    echo "No matching updates found to install."
    exit 0
fi

# Install the updates
for update in "${updates_to_install[@]}"; do
    echo "Installing: $update"
    # Execute the install command with the specific label
    $install_cmd "$update"
    
    # Check if installation was successful
    if [[ $? -eq 0 ]]; then
        echo "Successfully installed: $update"
    else
        echo "Failed to install: $update"
    fi
done

echo "Update process completed."

