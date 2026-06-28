#!/bin/bash
NAME=${1:-"snapshot"}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${SCRIPT_DIR}/snapshots/${NAME}"

# Derive the actual volume name from the Compose project
PROJECT=$(docker compose ls --format json 2>/dev/null | grep -o '"Name":"[^"]*"' | head -1 | cut -d'"' -f4)
if [ -z "$PROJECT" ]; then
  PROJECT=$(basename "$SCRIPT_DIR")
fi
DB_VOLUME="${PROJECT}_wp_db"

echo "Using volume: $DB_VOLUME"

# Verify it exists
if ! docker volume inspect "$DB_VOLUME" &>/dev/null; then
  echo "ERROR: Volume '$DB_VOLUME' not found. Run 'docker volume ls' to check."
  exit 1
fi

if [ -d "$DEST" ]; then
  read -rp "Snapshot '$NAME' already exists. Overwrite? [y/N] " CONFIRM
  [[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
  rm -rf "$DEST"
fi

mkdir -p "$DEST"

echo "Saving files..."
tar -czf "${DEST}/wp-content.tar.gz" -C "${SCRIPT_DIR}/data" wp-content
echo "Files saved."

echo "Saving database..."
mkdir -p "${DEST}/wp_db"
docker run --rm \
  -v "${DB_VOLUME}":/source \
  -v "${DEST}/wp_db":/dest \
  alpine sh -c "cp -a /source/. /dest/"

COUNT=$(ls "${DEST}/wp_db" | wc -l)
if [ "$COUNT" -eq 0 ]; then
  echo "WARNING: Database snapshot may have failed — wp_db folder is empty!"
else
  echo "Database saved ($COUNT files)."
fi

echo "Done — saved snapshot: $NAME"
