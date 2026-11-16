#!/usr/bin/env python3
"""Compare two raw images in 4 MiB blocks and save the runs of changed blocks.

Usage: super-diff.py OLD NEW OUTDIR
Writes OUTDIR/<start>_<count>.bin (start/count in 4 MiB blocks) and prints the list, so
only the changed parts of a partition image have to be written to the card:
  dd if=<start>_<count>.bin of=/dev/block/<part> bs=4194304 seek=<start>
"""
import os
import sys

BS = 4 << 20


def main():
    old_path, new_path, out = sys.argv[1:4]
    if os.path.getsize(old_path) != os.path.getsize(new_path):
        sys.exit("size differs: write the whole image")
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.endswith(".bin"):
            os.unlink(os.path.join(out, f))
    runs, cur = [], None
    with open(old_path, "rb") as a, open(new_path, "rb") as b:
        i = 0
        while True:
            x, y = a.read(BS), b.read(BS)
            if not y:
                break
            if x != y:
                if cur and cur[0] + cur[1] == i:
                    cur[1] += 1
                else:
                    cur = [i, 1]
                    runs.append(cur)
            i += 1
    total = 0
    with open(new_path, "rb") as b:
        for start, count in runs:
            b.seek(start * BS)
            with open(os.path.join(out, f"{start}_{count}.bin"), "wb") as o:
                o.write(b.read(count * BS))
            total += count
            print(f"{start}_{count}.bin")
    print(f"# {len(runs)} runs, {total * 4} MiB of {i * 4} MiB", file=sys.stderr)


if __name__ == "__main__":
    main()
