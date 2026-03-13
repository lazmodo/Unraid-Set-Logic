#!/bin/bash

# Start timer
START_TIME=$(date +%s)

# --- CONFIG ---
SOURCE_MOVIES="/mnt/user/Movies"
SOURCE_TV="/mnt/user/TV Shows"
DEST_DIR="/mnt/user/Backup/Backups/medialista"

# Future-proofing pool names


TIMESTAMP=$(date +%Y-%m-%d-%H-%M)
KEEP_DAYS=5

mkdir -p "$DEST_DIR"

MOVIE_FILE="$DEST_DIR/Movies_$TIMESTAMP.txt"
TV_FILE="$DEST_DIR/TVSeries_$TIMESTAMP.txt"

# --------------------------------------
# FUNCTION: Get Physical Disk (Concatenation Aware)
# --------------------------------------
get_physical_disk() {
    local full_path="$1"
    local found_disks=""
    
    # Extract the part of the path after /mnt/user/
    # e.g., "Movies/Avatar (2009)" or "TV Shows/Show/Season 01"
    local relative_path=${full_path#/mnt/user/}
    
    # Scavenger Loop: Check every physical mount point
    for d in /mnt/*; do
        # Ignore virtual paths
        [[ "$d" == "/mnt/user"* ]] && continue
        [[ "$d" == "/mnt/disks" ]] && continue
        
        # Check if this exact directory exists on this physical disk/pool
        if [[ -d "$d/$relative_path" ]]; then
            local disk_name="${d#/mnt/}"
            
            # Append disk name to our string
            if [[ -z "$found_disks" ]]; then
                found_disks="$disk_name"
            else
                found_disks="$found_disks, $disk_name"
            fi
        fi
    done

    if [[ -z "$found_disks" ]]; then
        echo "FUSE/Unknown"
    else
        echo "$found_disks"
    fi
}

# --------------------------------------
# PROCESS MOVIES
# --------------------------------------
declare -A DISK_STATS
printf "%-60s | %s\n" "Movie Title" "Disk(s)" > "$MOVIE_FILE"
printf "%-60s-+-%s\n" "------------------------------------------------------------" "-------------" >> "$MOVIE_FILE"

while IFS= read -r -d '' MOVIE; do
    TITLE=${MOVIE##*/}
    DISK=$(get_physical_disk "$MOVIE")
    ((DISK_STATS["$DISK"]++))
    printf "%-60.60s | %s\n" "$TITLE" "$DISK" >> "$MOVIE_FILE"
done < <(find "$SOURCE_MOVIES" -mindepth 1 -maxdepth 1 -type d -not -name ".*" -print0 | sort -z)

echo -e "\n\nDISK DISTRIBUTION SUMMARY:" >> "$MOVIE_FILE"
echo "---------------------------" >> "$MOVIE_FILE"
for d in "${!DISK_STATS[@]}"; do
    printf "%-15s : %d titles\n" "$d" "${DISK_STATS[$d]}" >> "$MOVIE_FILE"
done

# --------------------------------------
# PROCESS TV SHOWS (Season Level)
# --------------------------------------
unset DISK_STATS
declare -A DISK_STATS
printf "%-60s | %s\n" "TV Show - Season" "Disk(s)" > "$TV_FILE"
printf "%-60s-+-%s\n" "------------------------------------------------------------" "-------------" >> "$TV_FILE"

while IFS= read -r -d '' SEASON_PATH; do
    # Format: "Show Name - Season XX"
    SEASON_NAME=${SEASON_PATH##*/}
    PARENT_PATH=${SEASON_PATH%/*}
    SHOW_NAME=${PARENT_PATH##*/}
    DISPLAY_NAME="$SHOW_NAME - $SEASON_NAME"

    DISK=$(get_physical_disk "$SEASON_PATH")
    ((DISK_STATS["$DISK"]++))
    
    printf "%-60.60s | %s\n" "$DISPLAY_NAME" "$DISK" >> "$TV_FILE"
done < <(find "$SOURCE_TV" -mindepth 2 -maxdepth 2 -type d -not -name ".*" -print0 | sort -z)

echo -e "\n\nDISK DISTRIBUTION SUMMARY (By Season):" >> "$TV_FILE"
echo "---------------------------" >> "$TV_FILE"
for d in "${!DISK_STATS[@]}"; do
    printf "%-15s : %d seasons\n" "$d" "${DISK_STATS[$d]}" >> "$TV_FILE"
done

# --------------------------------------
# CLEANUP & FINISH
# --------------------------------------
find "$DEST_DIR" -type f \( -name "Movies_*.txt" -o -name "TVSeries_*.txt" \) -mtime +$KEEP_DAYS -delete

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "Media inventory generated with multi-disk season support ($TIMESTAMP)"
printf "Execution Time: %d:%02d\n" $((DURATION / 60)) $((DURATION % 60))
