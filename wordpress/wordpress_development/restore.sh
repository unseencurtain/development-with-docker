#!/bin/bash
NAME=$1
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PROJECT=$(docker compose ls --format json 2>/dev/null | grep -o '"Name":"[^"]*"' | head -1 | cut -d'"' -f4)
if [ -z "$PROJECT" ]; then
  PROJECT=$(basename "$SCRIPT_DIR")
fi
DB_VOLUME="${PROJECT}_wp_db"
echo "Using volume: $DB_VOLUME"

SNAP_DIR="${SCRIPT_DIR}/snapshots"

if [ -z "$NAME" ]; then
  SNAPS=()
  i=1
  while IFS= read -r snap; do
    [ -d "${SNAP_DIR}/${snap}" ] || continue
    echo "  [$i] $snap"
    SNAPS+=("$snap")
    ((i++))
  done < <(ls "${SNAP_DIR}" 2>/dev/null)

  if [ ${#SNAPS[@]} -eq 0 ]; then
    echo "No snapshots found in: $SNAP_DIR"
    exit 1
  fi

  echo ""
  read -rp "Pick a number: " PICK

  if ! [[ "$PICK" =~ ^[0-9]+$ ]] || [ "$PICK" -lt 1 ] || [ "$PICK" -gt ${#SNAPS[@]} ]; then
    echo "Invalid choice."
    exit 1
  fi

  NAME="${SNAPS[$((PICK-1))]}"
fi

SRC="${SNAP_DIR}/${NAME}"

if [ ! -d "$SRC" ]; then
  echo "Snapshot '$NAME' not found."
  exit 1
fi

echo ""
echo "Restoring from: $NAME"
read -rp "This will overwrite the live site. Are you sure? [y/N] " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

docker compose down
docker volume prune -f

echo "Restoring files..."
docker run --rm \
  -v "${SCRIPT_DIR}/data":/data \
  -v "${SRC}":/snapshot \
  alpine sh -c "rm -rf /data/wp-content && tar -xzf /snapshot/wp-content.tar.gz -C /data"

echo "Restoring database..."
docker run --rm -v "${DB_VOLUME}":/dest alpine sh -c "rm -rf /dest/*"
docker run --rm \
  -v "${SRC}/wp_db":/source \
  -v "${DB_VOLUME}":/dest \
  alpine sh -c "cp -a /source/. /dest/"

COUNT=$(docker run --rm -v "${DB_VOLUME}":/dest alpine sh -c "ls /dest | wc -l")
if [ "$COUNT" -eq 0 ]; then
  echo "WARNING: Database restore may have failed — volume is empty!"
else
  echo "Database OK ($COUNT files restored)"
fi

docker compose up -d
echo "Done — restored from: $NAME"
