#!/bin/bash

# Directory where GNOME saves screenshots
DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"

# Get the current time in seconds to know when we started
START_TIME=$(date +%s)

# 1. Trigger the GNOME Screenshot interactive portal
gdbus call --session \
    --dest org.freedesktop.portal.Desktop \
    --object-path /org/freedesktop/portal/desktop \
    --method org.freedesktop.portal.Screenshot.Screenshot \
    "" "{'interactive': <true>}" > /dev/null &

# 2. Wait up to 30 seconds for a new screenshot to appear in the folder
for i in {1..60}; do
    sleep 0.5
    # Find the newest file
    LATEST_FILE=$(ls -t "$DIR" 2>/dev/null | head -n 1)
    if [ -n "$LATEST_FILE" ]; then
        FILE_PATH="$DIR/$LATEST_FILE"
        FILE_MOD_TIME=$(stat -c %Y "$FILE_PATH")
        
        # Check if the file was created AFTER the script started
        if [ "$FILE_MOD_TIME" -ge "$START_TIME" ]; then
            # Wait a tiny bit to ensure GNOME has finished writing the file to disk
            sleep 0.2
            
            # 3. Run Tesseract OCR and copy to Wayland clipboard
            tesseract "$FILE_PATH" stdout -l eng 2>/dev/null | wl-copy
            
            # Notify the user
            notify-send -a "OCR Script" "OCR Complete" "Text extracted and copied to clipboard!"
            
            # Delete the temporary screenshot to keep your Pictures folder clean
            rm -f "$FILE_PATH"
            exit 0
        fi
    fi
done
exit 0
