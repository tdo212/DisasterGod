"""Print byte length + checksum for each src/ Luau file (matches the Luau checksum used when syncing inline)."""
import os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def checksum(b: bytes) -> int:
    s = 0
    for i, x in enumerate(b):
        s = (s + x * (i % 251 + 1)) % 2147483647
    return s
for dirpath, _, files in os.walk(os.path.join(ROOT, "src")):
    for f in sorted(files):
        if f.endswith(".luau"):
            p = os.path.join(dirpath, f)
            b = open(p, "rb").read()
            print(f"{os.path.relpath(p, ROOT).replace(os.sep, '/')} {len(b)} {checksum(b)}")
