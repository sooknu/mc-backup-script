#!/bin/bash

# This script uses rsync to create snapshots.
# Configuration
BUCKET_NAME="sooknu-mc"                  # Amazon S3 bucket name
BACKUP_DIR="/tmp/server-backups"         # Local directory to store temporary backups
DATE_FOLDER=$(date +%Y-%m-%d)              # Folder name in S3 for this backup's date
GRACE_PERIOD=15                          # Grace period in seconds before pausing the server
DEFAULT_FREQUENCY="daily"                # Default backup frequency
DRY_RUN=false                            # Dry run mode (true/false)
MAX_BACKUPS=7                            # Maximum number of backups to keep in S3
LOG_FILE="/home/ubuntu/backup-to-s3.log"   # Log file location

# Array to track which services have been paused
paused_services=()

# Ensure log file exists and has proper permissions
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

# Overwrite the log file each time the script runs
echo "Starting backup process - $(date '+%Y-%m-%d %H:%M:%S')" > "$LOG_FILE"

# Function to log messages with a timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to send a command to the server console via screen
send_server_command() {
    local session_name=$1
    local command=$2

    log "Sending command to $session_name: $command"
    screen -S "$session_name" -X stuff "$command\n"
}

# Function to pause server writes
pause_server_writes() {
    local session_name=$1

    log "Pausing writes for $session_name..."
    send_server_command "$session_name" "save-off"
    send_server_command "$session_name" "save-all"
    sleep 5  # Wait for pending writes to complete
}

# Function to resume server writes
resume_server_writes() {
    local session_name=$1

    log "Resuming writes for $session_name..."
    send_server_command "$session_name" "save-on"
}

# Function to handle errors and resume server writes if necessary
handle_error() {
    local error_message=$1
    local exit_script=${2:-false}  # Default to false (do not exit)

    log "ERROR: $error_message"
    if [ "$exit_script" = true ]; then
        log "Fatal error encountered. Resuming server writes before exiting..."
        for service in "${paused_services[@]}"; do
            resume_server_writes "$service"
        done
        log "Exiting script."
        exit 1
    fi
}

# Cleanup function for signal trapping
cleanup() {
    log "Script interrupted. Resuming server writes for any paused services..."
    for service in "${paused_services[@]}"; do
        resume_server_writes "$service"
    done
    exit 1
}

# Trap SIGINT and SIGTERM to ensure writes are resumed on interruption
trap cleanup SIGINT SIGTERM

# Check for required tools
if ! command -v aws &> /dev/null; then
    handle_error "AWS CLI is not installed. Please install it and configure credentials." true
fi

if ! command -v screen &> /dev/null; then
    handle_error "Screen is not installed. Please install it to run this script." true
fi

if ! command -v rsync &> /dev/null; then
    handle_error "rsync is not installed. Please install it to run this script." true
fi

# Validate S3 connectivity
if ! aws s3 ls "s3://$BUCKET_NAME/" &> /dev/null; then
    handle_error "Unable to access S3 bucket $BUCKET_NAME. Check permissions and network connectivity." true
fi

# Ensure the backup directory exists
mkdir -p "$BACKUP_DIR"

# Folders and services to backup
# Format: folder:service:frequency (service and frequency are optional)
CONFIGURATION=(
    "/home/ubuntu/lobby:lobby"
    "/home/ubuntu/mc2:mc2"
    "/home/ubuntu/mc1:mc1"
    "/home/ubuntu/velocity:velocity"
)

# Function to check if backup should run based on frequency
should_run_backup() {
    local frequency=$1
    case "$frequency" in
        daily)
            return 0 # Always run daily backups
            ;;
        weekly)
            [[ $(date +%u) -eq 7 ]] && return 0 # Run on Sundays
            ;;
        monthly)
            [[ $(date +%d) -eq 1 ]] && return 0 # Run on the 1st day of the month
            ;;
        *)
            log "Unknown frequency: $frequency. Skipping..."
            return 1
            ;;
    esac
    return 1
}

# Function to create a consistent snapshot using rsync
create_snapshot() {
    local source_dir=$1
    local snapshot_dir=$2

    log "Creating snapshot of $source_dir in $snapshot_dir..."
    if ! rsync -a --delete "$source_dir/" "$snapshot_dir/"; then
        handle_error "Failed to create snapshot of $source_dir."
        return 1
    fi
    return 0
}

# Function to compress the snapshot
compress_snapshot() {
    local snapshot_dir=$1
    local archive_file=$2

    log "Compressing snapshot $snapshot_dir into $archive_file..."
    if ! tar -czf "$archive_file" -C "$(dirname "$snapshot_dir")" "$(basename "$snapshot_dir")"; then
        handle_error "Failed to compress snapshot $snapshot_dir."
        return 1
    fi
    return 0
}

# Function to delete old backups from S3, keeping only the last MAX_BACKUPS
delete_old_backups() {
    log "Checking for old backups in S3 bucket $BUCKET_NAME..."
    # List all backup folders in the S3 bucket, sorted by date (oldest first)
    backup_folders=$(aws s3 ls "s3://$BUCKET_NAME/" | grep -E '^PRE [0-9]{4}-[0-9]{2}-[0-9]{2}/$' | awk '{print $2}' | sort)

    # Count the number of backup folders
    backup_count=$(echo "$backup_folders" | wc -l)

    # If there are more than MAX_BACKUPS, delete the oldest ones
    if [ "$backup_count" -gt "$MAX_BACKUPS" ]; then
        folders_to_delete=$(echo "$backup_folders" | head -n $((backup_count - MAX_BACKUPS)))
        log "Deleting old backups:"
        log "$folders_to_delete"
        for folder in $folders_to_delete; do
            if [ "$DRY_RUN" = false ]; then
                log "Deleting $folder from S3..."
                if ! aws s3 rm "s3://$BUCKET_NAME/$folder" --recursive; then
                    handle_error "Failed to delete $folder from S3."
                fi
            else
                log "[DRY RUN] Would delete $folder from S3."
            fi
        done
    else
        log "No old backups to delete."
    fi
}

# Notify users on all servers about the upcoming backup
log "Notifying users on all servers about the upcoming backup..."
for entry in "${CONFIGURATION[@]}"; do
    IFS=":" read -r folder service frequency <<< "$entry"
    frequency=${frequency:-$DEFAULT_FREQUENCY}
    if [ -n "$service" ]; then
        if [ "$DRY_RUN" = false ]; then
            send_server_command "$service" 'tellraw @a [{"text":"BACKUP STARTING IN '"$GRACE_PERIOD"' seconds... ","color":"yellow","bold":true}]'
        else
            log "[DRY RUN] Would notify users on $service about the backup."
        fi
    fi
done

# Wait for the grace period
sleep "$GRACE_PERIOD"

# Pause server writes and track paused services
log "Pausing server writes..."
for entry in "${CONFIGURATION[@]}"; do
    IFS=":" read -r folder service frequency <<< "$entry"
    if [ -n "$service" ]; then
        if [ "$DRY_RUN" = false ]; then
            pause_server_writes "$service"
            paused_services+=("$service")
            send_server_command "$service" 'tellraw @a [{"text":"BACKUP IN PROGRESS... ","color":"red","bold":true}]'
        else
            log "[DRY RUN] Would pause writes for $service."
        fi
    fi
done

# Process each entry in the configuration
for entry in "${CONFIGURATION[@]}"; do
    # Split the entry into folder, service, and frequency
    IFS=":" read -r folder service frequency <<< "$entry"

    # Ensure folder is defined
    if [ -z "$folder" ]; then
        handle_error "Folder is required. Skipping entry: $entry"
        continue
    fi

    # Apply default frequency if not specified
    frequency=${frequency:-$DEFAULT_FREQUENCY}

    # Debug: Print the resolved values
    log "Processing: folder=$folder, service=$service, frequency=$frequency"

    # Check if backup should run for this entry
    should_run_backup "$frequency"
    if [ $? -ne 0 ]; then
        log "Skipping $folder backup due to frequency setting ($frequency)."
        continue
    fi

    # Create a snapshot directory
    SNAPSHOT_DIR="$BACKUP_DIR/snapshot-$(basename "$folder")"
    mkdir -p "$SNAPSHOT_DIR"

    # Create a consistent snapshot
    if ! create_snapshot "$folder" "$SNAPSHOT_DIR"; then
        continue
    fi

    # Compress the snapshot
    ARCHIVE_FILE="$BACKUP_DIR/$(basename "$folder").tar.gz"
    if ! compress_snapshot "$SNAPSHOT_DIR" "$ARCHIVE_FILE"; then
        continue
    fi

    # Clean up the snapshot directory
    rm -rf "$SNAPSHOT_DIR"

    # Upload the compressed file to S3 inside a date-specific folder
    S3_PATH="s3://$BUCKET_NAME/$DATE_FOLDER/"
    log "Uploading $ARCHIVE_FILE to $S3_PATH..."
    if [ "$DRY_RUN" = false ]; then
        if ! aws s3 cp "$ARCHIVE_FILE" "$S3_PATH"; then
            handle_error "Failed to upload $ARCHIVE_FILE to S3. Keeping local backup for troubleshooting."
        else
            log "Uploaded $ARCHIVE_FILE successfully. Deleting local archive..."
            rm -f "$ARCHIVE_FILE"
        fi
    else
        log "[DRY RUN] Would upload $ARCHIVE_FILE to $S3_PATH."
    fi
done

# Resume server writes for all services
log "Resuming server writes..."
for entry in "${CONFIGURATION[@]}"; do
    IFS=":" read -r folder service frequency <<< "$entry"
    if [ -n "$service" ]; then
        if [ "$DRY_RUN" = false ]; then
            resume_server_writes "$service"
            send_server_command "$service" 'tellraw @a [{"text":"BACKUP COMPLETED. ","color":"green","bold":true}]'
        else
            log "[DRY RUN] Would resume writes for $service."
        fi
    fi
done

# Delete old backups from S3
delete_old_backups

# Final cleanup
log "Cleaning up temporary backup directory..."
rm -rf "$BACKUP_DIR"

log "Backup process completed."
