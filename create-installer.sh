#!/bin/bash

# Take output filename as first argument, fallback to "pmx.sh"
OUTPUT_FILE="${1:-pmx.sh}"

# Write stub inline
echo "Creating self-extracting script: $OUTPUT_FILE..."
cat > "$OUTPUT_FILE" <<'EOF'
#!/bin/bash
# Self-extracting Proxmox Idempotent Runner
# Usage: ./proxmox-runner.sh [--dry-run] [--plan-file plan.sh]

set -e

# Create temp dir for extraction
TMPDIR=$(mktemp -d)
echo "⚡ Extracting scripts to $TMPDIR ..."

# Find line number where tarball starts
TAR_LINE=$(grep -an '^__TARALL_START__$' "$0" | cut -d: -f1)
TAR_LINE=$((TAR_LINE + 1))  # start from next line

# Extract appended tarball
tail -n +$TAR_LINE "$0" | tar -xz -C "$TMPDIR"

# Make runner and steps executable
chmod +x "$TMPDIR/runner.py"
chmod +x "$TMPDIR/runner-steps/"*.sh

# Run the Python runner with any arguments passed
cd "$TMPDIR"
python3 runner.py "$@"

# Clean up
rm -rf "$TMPDIR"

exit 0

__TARALL_START__
EOF

# Create gzip-compressed tarball of runner and steps
echo " - Creating tarball..."
tar czf temp-tarball.tgz runner.py runner-steps/

# Append tarball to stub
echo " - Appending tarball to script..."
cat temp-tarball.tgz >> "$OUTPUT_FILE"
rm temp-tarball.tgz

# # Append tarball to stub
# echo " - Compressing files and appending to script..."
# tar czf - runner.py runner-steps/ | tee -a "$OUTPUT_FILE" > /dev/null

# Make final script executable
echo " - Making final script executable..."
chmod +x "$OUTPUT_FILE"

echo "Done"
