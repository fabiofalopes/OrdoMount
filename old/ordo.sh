#!/bin/bash

# Define main function drive to encapsulate all operations
drive() {

    # Helper Function: Print help
    print_help() {
        echo "drive: Script to manage rclone connected remote drives"
        echo "Usage:"
        echo "  drive -m       Mount a remote drive"
        echo "  drive -u       Unmount a remote drive"
        echo "  drive          Show this help message"
    }

    # Function to get the list of drives
    get_drives() {
        # Using command substitution along with a subshell to process each line output by 'rclone listremotes'
        local drives=()
        while read -r line; do
            # Remove the colon at the end of each line and add to array
            drives+=("${line%:}")
        done < <(rclone listremotes)
        echo "${drives[@]}"  # Output all elements of the array
    }

    # Function to print drives menu
    print_menu() {
        local drives_list=($(get_drives))  # Retrieve the list of drives into array
        local count=1
        echo "Debug: Full drive list: ${drives_list[*]}"
        for drive in "${drives_list[@]}"; do
            echo "$count. $drive"
            let count++
        done
        echo "Debug: Number of drives listed: ${#drives_list[@]}"
        return ${#drives_list[@]}  # Return the count of drives
    }

        # Function to mount the drive
    mount_drive() {
        echo "Available drives to mount:"
        print_menu  # This displays the menu to list available drives
        echo "Select the number of the drive you want to mount:"
        read DRIVE_INDEX
        let DRIVE_INDEX--  # Correct for zero-based index

        local drives_list=($(get_drives))
        if [[ $DRIVE_INDEX -lt 0 || $DRIVE_INDEX -ge ${#drives_list[@]} ]]; then
            echo "Invalid drive number. Please run the script again with valid input."
            return
        fi

        local DRIVE_NAME=${drives_list[$DRIVE_INDEX]}
        local DRIVE_NAME_WITH_COLON="$DRIVE_NAME:"
        local MOUNT_PATH="/home/$USER/mounts/$DRIVE_NAME"

        mkdir -p "$MOUNT_PATH"
        echo "Mounting $DRIVE_NAME_WITH_COLON to $MOUNT_PATH..."
        rclone mount "$DRIVE_NAME_WITH_COLON" "$MOUNT_PATH" --allow-non-empty --daemon
        echo "$DRIVE_NAME mounted at $MOUNT_PATH"
    }

    # Function to unmount the drive
    unmount_drive() {
        echo "Available drives to unmount:"
        print_menu  # This displays the menu to list available drives
        echo "Select the number of the drive you want to unmount:"
        read DRIVE_INDEX
        let DRIVE_INDEX--  # Correct for zero-based index

        local drives_list=($(get_drives))
        if [[ $DRIVE_INDEX -lt 0 || $DRIVE_INDEX -ge ${#drives_list[@]} ]]; then
            echo "Invalid drive number. Please run the script again with valid input."
            return
        fi

        local DRIVE_NAME=${drives_list[$DRIVE_INDEX]}
        local DRIVE_NAME_WITH_COLON="$DRIVE_NAME:"
        local MOUNT_PATH="/home/$USER/mounts/$DRIVE_NAME"

        echo "Unmounting $DRIVE_NAME_WITH_COLON from $MOUNT_PATH..."
        fusermount -uz "$MOUNT_PATH"
        echo "$DRIVE_NAME unmounted from $MOUNT_PATH"
    }

    # Handling command-line arguments
    if [[ "$1" = "-m" ]]; then
        mount_drive
    elif [[ "$1" = "-u" ]]; then
        unmount_drive
    else
        print_help
    fi
}

# Allows the script to be sourced from bash directly which would only define the function
# but not call it, until the user calls it manually.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    drive "$@"
fi