#!/usr/bin/env bash
set -euo pipefail
start_time=$(date +%s)

# Usage: merge_gopro7.sh <directory-with-mp4s>
# Requires: mp4_merge-mac-arm64 located next to this script (same directory)
# Groups GoPro Hero7 GXccssss (.MP4 or .mp4) chunks by the trailing 4-digit sequence,
# sorts each group by chapter (cc, numeric ascending),
# runs the merger for multi-part sequences, for single-part sequences copies to GX<seq>_joined.mp4 in the same input directory.
# Portable for macOS bash (avoids ${var^^} and mapfile which are not available on macOS bash 3.2).

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <directory-with-gopro-files>"
  exit 1
fi

INPUT_DIR="$1"
if [ ! -d "$INPUT_DIR" ]; then
  echo "Error: not a directory: $INPUT_DIR"
  exit 1
fi

# locate merger next to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MERGER="$SCRIPT_DIR/mp4_merge-mac-arm64"
if [ ! -x "$MERGER" ]; then
  echo "Error: merger not found or not executable: $MERGER"
  exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# collect mp4 files (both .MP4 and .mp4)
shopt -s nullglob
mp4_list=( "$INPUT_DIR"/*.[mM][pP]4 )

if [ "${#mp4_list[@]}" -eq 0 ]; then
  echo "No mp4 files found in $INPUT_DIR"
  exit 0
fi

# Build per-sequence temporary lists with lines: "<chapter><TAB><full_path>"
for f in "${mp4_list[@]}"; do
  name="${f##*/}"
  up="$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')" # portable uppercase

  if [[ $up =~ ^GX([0-9]{2})([0-9]{4})\.MP4$ ]]; then
    chapter="${BASH_REMATCH[1]}"
    seq="${BASH_REMATCH[2]}"
    chapter=$((10#$chapter))
  else
    continue
  fi

  printf '%d\t%s\n' "$chapter" "$f" >> "$TMPDIR/seq_$seq"
done

created=0

# Process each sequence file
for seqfile in "$TMPDIR"/seq_*; do
  [ -f "$seqfile" ] || continue
  seq="${seqfile##*_}"

  sorted="$seqfile.sorted"
  awk -F'\t' '!seen[$2]++ { print $0 }' "$seqfile" | sort -n -t$'\t' -k1,1 > "$sorted"

  paths=()
  while IFS= read -r p; do
    paths+=("$p")
  done < <(cut -f2 -d$'\t' "$sorted")

  if [ "${#paths[@]}" -eq 0 ]; then
    rm -f "$sorted"
    continue
  fi

  outname="GX${seq}_joined.mp4"
  outpath="$INPUT_DIR/$outname"

  if [ "${#paths[@]}" -gt 1 ]; then
    echo "Merging sequence $seq:"
    for p in "${paths[@]}"; do printf '  %s\n' "$p"; done

    "$MERGER" "${paths[@]}" -o "$outpath"
    rc=$?
    if [ $rc -eq 0 ]; then
      echo "Sequence $seq merged successfully to $outname."
      created=$((created+1))
    else
      echo "Error merging sequence $seq (exit code $rc)."
    fi
  else
    src="${paths[0]}"
    echo "Copying single part file $(basename "$src") to $outname"
    cp -p "$src" "$outpath"
    created=$((created+1))
  fi

  rm -f "$sorted"
done

end_time=$(date +%s)
elapsed=$(( end_time - start_time ))
hours=$(( elapsed / 3600 ))
minutes=$(( (elapsed % 3600) / 60 ))
seconds=$(( elapsed % 60 ))

echo "Processing complete. Created or copied ${created} merged video file(s)."
printf "Total time: %02d:%02d:%02d (hh:mm:ss)\n" "$hours" "$minutes" "$seconds"