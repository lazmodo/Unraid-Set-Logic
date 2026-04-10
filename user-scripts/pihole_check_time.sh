#!/bin/bash

START_TIME=$(date +%s)

# --- CONFIGURATION ---
PI_USER="REPLACE_WITH_USER"
PI_IP="REPLACE_WITH_IP"
SSH_KEY="/path/to/your/key" # Optional: specify key
DRIFT_THRESHOLD=30  # Seconds before an update is forced
SSH_OPTS="-i $SSH_KEY -o BatchMode=yes -o ConnectTimeout=5"
#ASSUMPTION: SSH Key is setup between unraid & PI_IP


# 1. Get current time from both systems
UNRAID_TIME=$(date +%s)
PI_TIME=$(ssh -i "$SSH_KEY" $PI_USER@$PI_IP "date +%s")

# 2. Check if we actually got a response from the Pi
if [ -z "$PI_TIME" ]; then
    echo "Error: Could not retrieve time from Pi. Check connection or IP."
    # Optional: Notify Unraid if the Pi is completely unreachable
    /usr/local/emhttp/webGui/scripts/notify -i alert -s "Pi-Sync Connection Error" -d "Could not reach Pi at $PI_IP via SSH."
    exit 1
fi

# 3. Calculate the absolute difference
DIFF=$(( UNRAID_TIME - PI_TIME ))
ABS_DIFF=${DIFF#-} # Strips the negative sign if Pi is ahead of Unraid

printf "Unraid Time: %s\n" "$(date -d @$UNRAID_TIME)"
printf "Pi Time:     %s\n" "$(date -d @$PI_TIME)"
printf "Time Drift:  %d seconds\n" "$ABS_DIFF"

# 4. Update if drift exceeds threshold
if [ "$ABS_DIFF" -gt "$DRIFT_THRESHOLD" ]; then
    echo "Drift exceeds $DRIFT_THRESHOLD seconds. Pushing update..."
    
    NEW_TIME=$(date +"%Y-%m-%d %H:%M:%S")

    ssh $SSH_OPTS $PI_USER@$PI_IP "
        sudo systemctl stop systemd-timesyncd
        sudo date -s '$NEW_TIME'
        sudo pihole -f
        sudo systemctl start systemd-timesyncd
    "
    
    if [ $? -eq 0 ]; then
        echo "Success: Pi time synchronized to Unraid."
        # Dashboard notification only on successful adjustment
        /usr/local/emhttp/webGui/scripts/notify -i normal -s "Pi-Sync Success" -d "Time drift of $ABS_DIFF seconds corrected for $PI_IP."
    else
        echo "Error: Failed to update Pi time."
        /usr/local/emhttp/webGui/scripts/notify -i alert -s "Pi-Sync Script Error" -d "SSH connected, but 'date' or 'systemctl' command failed on $PI_IP."
    fi
else
    # Stay silent on the dashboard, just log it in the User Script window
    echo "Time is within acceptable range ($ABS_DIFF seconds). No update needed."
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

printf "Execution Time: %d:%02d\n" $((DURATION / 60)) $((DURATION % 60))
