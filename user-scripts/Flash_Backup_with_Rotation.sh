#!/bin/bash

# Start timer
START_TIME=$(date +%s)

# ==============================
# Unraid Flash Backup Script
# Incremental + Hardlink Rotation
# ==============================

# --- CONFIGURATION ---
SOURCE="/boot/"
DEST="/mnt/user/Backup/Backups/unraid_flashdrive"

DAILY=7
WEEKLY=4
MONTHLY=6

LOG="/var/log/unraid_flash_backup.log"
LATEST="$DEST/latest"

LOCK_FILE="/tmp/unraid_flash_backup.lock"
NOTIFY="/usr/local/emhttp/webGui/scripts/notify"

KEYFILE=$(ls "$DEST/daily.0/config/"*.key 2>/dev/null)

# Files to exclude (live boot OS safety)
EXCLUDES=(
    "--exclude=ldlinux.sys"
    "--exclude=ldlinux.c32"
    "--exclude=config/plugins/dynamix.file.integrity"
    "--exclude=config/super.dat"
    "--exclude=config/plugins-error.log"
    "--exclude=*.log"
    "--exclude=previous/"
)
# --- -----------------

# Prevent concurrent runs
exec 200>"$LOCK_FILE"
flock -n 200 || exit 1

# Verify Flash drive is actually mounted
if ! mountpoint -q /boot; then
    echo "$(date "+%Y-%m-%d %H:%M:%S") [ERROR]: /boot is not a valid mountpoint. Backup aborted." >> "$LOG"
    /usr/local/emhttp/webGui/scripts/notify -i alert -s "Flash Backup Failed" -d "/boot is not mounted"
    exit 1
fi


echo "$(date) Starting flash backup" >> "$LOG"

mkdir -p "$DEST"

# --------------------------
# Rotation Function
# --------------------------
rotate_backups () {
    local prefix=$1
    local max=$2

    for (( i=max-1; i>=0; i-- )); do
        if [ -d "$DEST/$prefix.$i" ]; then
            if [ $i -eq $((max-1)) ]; then
                rm -rf "$DEST/$prefix.$i"
            else
                mv "$DEST/$prefix.$i" "$DEST/$prefix.$((i+1))"
            fi
        fi
    done
}

# --------------------------
# Rotate Daily Backups
# --------------------------
rotate_backups daily $DAILY

# Determine link-dest (previous backup)
LINK=""
[ -d "$DEST/daily.1" ] && LINK="--link-dest=$DEST/daily.1"

# --------------------------
# Perform Incremental Backup
# --------------------------
rsync -rt \
--delete-delay \
--modify-window=1 \
--delay-updates \
--numeric-ids \
--itemize-changes \
"${EXCLUDES[@]}" \
${LINK:+$LINK} \
"$SOURCE" "$DEST/daily.0" >> "$LOG" 2>&1

# --------------------------
# Weekly Promotion (Sunday)
# --------------------------
if [ "$(date +%u)" -eq 7 ]; then
    rotate_backups weekly $WEEKLY
    cp -al "$DEST/daily.0" "$DEST/weekly.0"
fi

# --------------------------
# Monthly Promotion (1st Day)
# --------------------------
if [ "$(date +%d)" -eq 01 ]; then
    rotate_backups monthly $MONTHLY
    cp -al "$DEST/daily.0" "$DEST/monthly.0"
fi

# --------------------------
# Update Latest Symlink
# --------------------------
rm -f "$LATEST"
ln -s "daily.0" "$LATEST"

# --------------------------
# Weekly Integrity Check
# --------------------------
if [ "$(date +%u)" -eq 7 ]; then
    echo "$(date) Running flash integrity verification" >> "$LOG"

    VERIFY=$(rsync -rcn \
        --exclude="ldlinux.*" \
        "$SOURCE" "$DEST/daily.0")

    if [ -n "$VERIFY" ]; then
        echo "$(date) WARNING: Verification mismatch detected" >> "$LOG"

        "$NOTIFY" \
            -i warning \
            -s "Flash Backup Warning" \
            -d "Flash backup verification mismatch detected. Check log."
    else
        echo "$(date) Flash verification successful" >> "$LOG"
    fi
fi

# Verify License Key exists in the new backup
if [ -z "$KEYFILE" ]; then
    echo "$(date) CRITICAL: License key missing from backup!" >> "$LOG"
    "$NOTIFY" -i alert -s "Flash Backup" -d "CRITICAL: Pro/Plus/Basic .key file not found in backup!"
fi

echo "$(date) Flash backup complete" >> "$LOG"

# Fix permissions for SMB access
newperms "$DEST"

"$NOTIFY" \
    -i normal \
    -s "Flash Backup" \
    -d "Unraid flash backup completed successfully."
    


END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))


printf "Execution Time: %d:%02d\n" $((DURATION / 60)) $((DURATION % 60))
