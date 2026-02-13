#!/bin/bash
# Script to regenerate .cargo-checksum.json files after trimming vendor directory
# This is necessary because cargo verifies that all files listed in the checksum exist

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <vendor_directory>"
    exit 1
fi

VENDOR_DIR="$1"

if [ ! -d "$VENDOR_DIR" ]; then
    echo "Error: Directory $VENDOR_DIR does not exist"
    exit 1
fi

echo "Regenerating checksums for vendored crates in $VENDOR_DIR..."

crate_count=0
for crate_dir in "$VENDOR_DIR"/*/; do
    checksum_file="${crate_dir}.cargo-checksum.json"
    
    if [ ! -f "$checksum_file" ]; then
        continue
    fi
    
    crate_count=$((crate_count + 1))
    
    # Extract package checksum (this doesn't change - it's the hash of the original .crate file)
    if command -v jq >/dev/null 2>&1; then
        package_checksum=$(jq -r '.package' "$checksum_file" 2>/dev/null || echo "null")
    else
        # Fallback if jq not available - extract using grep/sed
        package_checksum=$(grep -o '"package":"[^"]*"' "$checksum_file" | sed 's/"package":"\([^"]*\)"/\1/')
    fi
    
    # Start building new checksum JSON
    temp_file="${checksum_file}.tmp"
    echo -n '{"files":{' > "$temp_file"
    
    first=true
    # Find all files in the crate directory (excluding .cargo-checksum.json itself)
    while IFS= read -r -d '' file; do
        # Get relative path from crate directory
        rel_path="${file#$crate_dir}"
        
        # Skip the checksum file itself
        if [ "$rel_path" = ".cargo-checksum.json" ] || [ "$rel_path" = ".cargo-checksum.json.tmp" ]; then
            continue
        fi
        
        # Compute SHA256
        if command -v sha256sum >/dev/null 2>&1; then
            hash=$(sha256sum "$file" | cut -d' ' -f1)
        elif command -v shasum >/dev/null 2>&1; then
            hash=$(shasum -a 256 "$file" | cut -d' ' -f1)
        else
            echo "Error: No SHA256 tool found (need sha256sum or shasum)"
            exit 1
        fi
        
        # Add comma if not first entry
        if [ "$first" = true ]; then
            first=false
        else
            echo -n ',' >> "$temp_file"
        fi
        
        # Escape path for JSON - use jq if available for proper escaping
        if command -v jq >/dev/null 2>&1; then
            # jq properly handles all JSON special characters
            # Use -Rs to read as raw string and output as JSON string (with quotes)
            # Then strip the quotes that jq adds
            escaped_path=$(echo -n "$rel_path" | jq -Rs '.' | sed 's/^"//; s/"$//')
            echo -n "\"$escaped_path\":\"$hash\"" >> "$temp_file"
        else
            # Fallback: basic escaping for backslash and quote only
            # Note: This doesn't handle all JSON special chars properly
            # If filenames contain newlines, tabs, etc., jq is required
            escaped_path=$(echo "$rel_path" | sed 's/\\/\\\\/g; s/"/\\"/g')
            echo -n "\"$escaped_path\":\"$hash\"" >> "$temp_file"
        fi
        
    done < <(find "$crate_dir" -type f ! -name ".cargo-checksum.json" ! -name ".cargo-checksum.json.tmp" -print0 2>/dev/null)
    
    # Close files object and add package checksum
    echo -n '},"package":' >> "$temp_file"
    if [ "$package_checksum" = "null" ] || [ -z "$package_checksum" ]; then
        echo -n 'null' >> "$temp_file"
    else
        echo -n "\"$package_checksum\"" >> "$temp_file"
    fi
    echo '}' >> "$temp_file"
    
    # Replace old checksum file
    mv "$temp_file" "$checksum_file"
done

echo "Regenerated checksums for $crate_count crates"
