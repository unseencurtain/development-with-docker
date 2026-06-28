#!/bin/bash

SNAPS=()
if [ -d "./snapshots" ]; then
  while IFS= read -r snap; do
    SNAPS+=("$snap")
  done < <(ls ./snapshots 2>/dev/null)
fi

echo "What do you want to delete?"
echo ""

i=1
for SNAP in "${SNAPS[@]}"; do
  echo "  [$i] snapshot: $SNAP"
  ((i++))
done

ALL_INDEX=$i
echo "  [$ALL_INDEX] ALL snapshots + live data (full nuke)"
echo "  [q] Quit"
echo ""
read -rp "Pick a number: " PICK

if [[ "$PICK" == "q" ]]; then
  echo "Aborted."
  exit 0
fi

if ! [[ "$PICK" =~ ^[0-9]+$ ]]; then
  echo "Invalid choice."
  exit 1
fi

if [ "$PICK" -eq "$ALL_INDEX" ]; then
  echo ""
  echo "This will delete ALL snapshots, ./data, and the database volume."
  read -rp "Type 'yes' to confirm: " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
  fi
  docker compose down -v
  rm -rf ./data ./snapshots
  echo "Everything nuked."

elif [ "$PICK" -ge 1 ] && [ "$PICK" -le ${#SNAPS[@]} ]; then
  NAME="${SNAPS[$((PICK-1))]}"
  echo ""
  read -rp "Delete snapshot '$NAME'? [y/N] " CONFIRM
  [[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
  rm -rf "./snapshots/${NAME}"
  echo "Deleted snapshot: $NAME"

else
  echo "Invalid choice."
  exit 1
fi
