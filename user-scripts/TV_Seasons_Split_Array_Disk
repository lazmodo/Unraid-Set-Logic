#!/bin/bash

START_TIME=$(date +%s)

SOURCE_TV="TV Shows"
DEST_DIR="/mnt/user/Backup/Backups/medialista"

TIMESTAMP=$(date +%Y-%m-%d-%H-%M)
KEEP_DAYS=5

mkdir -p "$DEST_DIR"

REPORT="$DEST_DIR/Split_Seasons_$TIMESTAMP.txt"
TEMP_FILE=$(mktemp)

declare -A SEASON_DISKS

# --------------------------------------
# Scan each disk once
# --------------------------------------

for DISK in /mnt/disk[0-9]*; do

    DISK_NAME=$(basename "$DISK")

    TV_PATH="$DISK/$SOURCE_TV"

    [[ ! -d "$TV_PATH" ]] && continue

    while IFS= read -r -d '' SEASON; do

        RELATIVE="${SEASON#"$DISK/"}"

        # Format display name
        SEASON_NAME=${SEASON##*/}
        SHOW_PATH=${SEASON%/*}
        SHOW_NAME=${SHOW_PATH##*/}

        DISPLAY="$SHOW_NAME - $SEASON_NAME"

        if [[ -z ${SEASON_DISKS[$DISPLAY]} ]]; then
            SEASON_DISKS[$DISPLAY]="$DISK_NAME"
        else
            SEASON_DISKS[$DISPLAY]+=",$DISK_NAME"
        fi

    done < <(find "$TV_PATH" -mindepth 2 -maxdepth 2 -type d -print0)

done

# --------------------------------------
# Detect splits
# --------------------------------------

COUNT=0

for s in "${!SEASON_DISKS[@]}"; do

    DISKS="${SEASON_DISKS[$s]}"

    IFS=',' read -ra disk_list <<< "$DISKS"

    if (( ${#disk_list[@]} > 1 )); then
        printf "%-60s | %s\n" "$s" "$DISKS" >> "$TEMP_FILE"
        ((COUNT++))
    fi

done


# --------------------------------------
# Write report
# --------------------------------------

echo "TV Seasons Spanning Multiple Array Disks" > "$REPORT"
echo "-----------------------------------------" >> "$REPORT"

sort "$TEMP_FILE" >> "$REPORT"

echo "" >> "$REPORT"
echo "Total Split Seasons: $COUNT" >> "$REPORT"

rm "$TEMP_FILE"

# --------------------------------------
# Cleanup
# --------------------------------------

find "$DEST_DIR" -type f -name "Split_Seasons_*.txt" -mtime +$KEEP_DAYS -delete


END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "Split season scan complete ($TIMESTAMP)"
printf "Execution Time: %d:%02d\n" $((DURATION / 60)) $((DURATION % 60))
