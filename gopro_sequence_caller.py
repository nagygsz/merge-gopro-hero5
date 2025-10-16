import sys
import re
import subprocess
import shutil
from pathlib import Path
from collections import defaultdict

def find_gopro_sequences(folder_path):
    folder = Path(folder_path)
    mp4_files = list(folder.glob('*.MP4')) + list(folder.glob('*.mp4'))

    sequences = defaultdict(list)
    for mp4_file in mp4_files:
        filename = mp4_file.name.upper()

        gopr_match = re.match(r'GOPR(\d{4})\.MP4', filename)
        if gopr_match:
            seq_num = gopr_match.group(1)
            sequences[seq_num].append((0, mp4_file))
            continue

        gp_match = re.match(r'GP(\d{2})(\d{4})\.MP4', filename)
        if gp_match:
            chapter_num = int(gp_match.group(1))
            seq_num = gp_match.group(2)
            sequences[seq_num].append((chapter_num, mp4_file))

    organized = {}
    for seq, files in sequences.items():
        # Remove duplicates
        unique_files = []
        seen = set()
        for _, file in files:
            if file not in seen:
                unique_files.append(file)
                seen.add(file)
        # Sort by chapter number for multi-part sequences
        sorted_files = [f for _, f in sorted(zip([f[0] for f in files if f[1] in unique_files], unique_files))]
        organized[seq] = sorted_files
    return organized

def copy_single_file(file_path):
    dest = file_path.parent / (file_path.name + '_joined.mp4')
    print(f'Copying single part file {file_path.name} to {dest.name}')
    shutil.copy2(file_path, dest)

def main():
    if len(sys.argv) != 3:
        print("Usage: python script.py <folder_with_gopro_files> <path_to_mp4_merge_exe>")
        sys.exit(1)

    input_folder = sys.argv[1]
    merger_exe = sys.argv[2]

    sequences = find_gopro_sequences(input_folder)

    if not sequences:
        print("No GoPro files found to process.")
        sys.exit(0)

    total_sequences = len(sequences)
    total_files = sum(len(files) for files in sequences.values())
    print(f"Found {total_files} GoPro video files forming {total_sequences} sequences to process.\n")

    created_files_count = 0

    # Process each sequence
    for seq_num, files in sequences.items():
        if len(files) > 1:
            cmd = [merger_exe] + [str(f) for f in files]
            print(f"Executing merge command for sequence {seq_num}: {' '.join(cmd)}")
            result = subprocess.run(cmd)
            if result.returncode == 0:
                print(f"Sequence {seq_num} merged successfully.")
                created_files_count += 1
            else:
                print(f"Error merging sequence {seq_num}.")
        else:
            copy_single_file(files[0])
            created_files_count += 1

    print(f"\nProcessing complete. Created or copied {created_files_count} merged video file(s).")

if __name__ == '__main__':
    main()
