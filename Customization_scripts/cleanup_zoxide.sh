#!/bin/bash

# cleanup_zoxide.sh
# Removes non-existent directories from zoxide's database

# Check if zoxide is installed
if ! command -v zoxide &> /dev/null; then
    echo "Error: zoxide is not installed or not in your PATH."
    exit 1
fi

echo "Checking zoxide database for stale paths..."

stale_count=0

# Loop through all directories currently tracked by zoxide
while IFS= read -r dir; do
    # Check if the path is NOT a valid directory anymore
    if [ ! -d "$dir" ]; then
        echo "Removing stale path: $dir"
        zoxide remove "$dir"
        ((stale_count++))
    fi
done < <(zoxide query -l)

if [ "$stale_count" -eq 0 ]; then
    echo "Zoxide database is already clean! No stale paths found."
else
    echo "Successfully removed $stale_count stale path(s) from zoxide."
fi
