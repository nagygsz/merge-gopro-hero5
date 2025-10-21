# merge-gopro-hero5 (mac)

Small macOS bash script that groups GoPro split chunks (GOPR#### / GPcc####) and merges sequences with mp4_merge-mac-arm64.

Prerequisites: macOS (bash 3.2 compatible) and mp4_merge-mac-arm64 from
https://github.com/gyroflow/mp4-merge/releases/tag/v0.1.11 placed next to the script.

Install:
chmod +x merge_gopro.sh mp4_merge-mac-arm64

Usage:
./merge_gopro.sh "/path/to/100GOPRO"
Example:
./merge_gopro.sh "/Volumes/SP DS72/100GOPRO"

What it does:
- Groups files by trailing 4-digit sequence.
- Orders parts (GOPR = chapter 0, then GPcc ascending).
- Multi-part: runs mp4_merge-mac-arm64; single-part: copies to <name>_joined.mp4.

Notes:
Quote paths with spaces. If CRLF errors appear, convert line endings:
tr -d '\r' < merge_gopro.sh > /tmp/merge_gopro.sh && mv /tmp/merge_gopro.sh merge_gopro.sh