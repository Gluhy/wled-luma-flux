#!/usr/bin/env python3
"""Builds the ESP32 partition table WLED needs on a 4 MB board.

The WLED web installer publishes ready-made tables for 8 MB and 16 MB boards
only, so for a plain 4 MB ESP32 the table has to be produced locally. The
format is simple enough that generating it here beats pulling in a copy of
esp-idf just for one 3 KB file.

    make_partitions.py partitions.bin
"""
import hashlib
import struct
import sys

# WLED's own layout for 4 MB flash with a 960 KB filesystem
# (tools/WLED_ESP32_4MB_1MB_FS.csv in the WLED source tree).
#   name,      type, subtype, offset,     size
TABLE = [
    ("nvs",     1, 0x02, 0x009000, 0x005000),
    ("otadata", 1, 0x00, 0x00e000, 0x002000),
    ("app0",    0, 0x10, 0x010000, 0x180000),
    ("app1",    0, 0x11, 0x190000, 0x180000),
    ("spiffs",  1, 0x82, 0x310000, 0x0F0000),
]

ENTRY_MAGIC = 0x50AA
MD5_MAGIC = 0xEBEB
TABLE_SIZE = 0x0C00          # the partition table always occupies 3 KB


def build():
    blob = b""
    for name, ptype, subtype, offset, size in TABLE:
        blob += struct.pack("<HBBLL16sL", ENTRY_MAGIC, ptype, subtype,
                            offset, size, name.encode(), 0)
    # esp-idf appends an MD5 of the entries so the bootloader can detect
    # a truncated or corrupted table
    blob += struct.pack("<H", MD5_MAGIC) + b"\xff" * 14 + hashlib.md5(blob).digest()
    return blob + b"\xff" * (TABLE_SIZE - len(blob))


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out = sys.argv[1]
    data = build()
    with open(out, "wb") as f:
        f.write(data)
    total = sum(size for _, _, _, _, size in TABLE)
    print("Wrote %s (%d bytes, %d partitions, %.1f MB mapped)"
          % (out, len(data), len(TABLE), total / 1048576.0))


if __name__ == "__main__":
    main()
