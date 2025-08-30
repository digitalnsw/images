#!/usr/bin/env bash
set -euo pipefail

IN_DIR="${1:-./in}"      # input folder (default: ./in)
OUT_DIR="${2:-./out}"    # output folder (default: ./out)
SIZES=(
"248x200"
"224x126"
)

mkdir -p "$OUT_DIR"
shopt -s nullglob nocaseglob

# Process common image types in the input folder
for f in "$IN_DIR"/*.{jpg,jpeg,png,webp,gif}; do
  base="$(basename "$f")"
  ext="${base##*.}"
  name="${base%.*}"

  for sz in "${SIZES[@]}"; do
    mkdir -p "$OUT_DIR/$sz"
    # Resize to fill, then center-extent to exact size (no distortion)
    magick "$f" -auto-orient -strip \
      -thumbnail "$sz^" -gravity center -extent "$sz" \
      "$OUT_DIR/$sz/$name.$ext"
  done
done

echo "Done. Check $OUT_DIR/<size>/ for results."
