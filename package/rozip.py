#!/usr/bin/env python3
"""Zip files and directories for RISC OS, keeping filetypes.

   package/rozip.py OUT.zip [-C DIR] PATH...

PATHs are relative to DIR (default: the current directory) and are stored
under those names, so "-C dist !Hello" stores !Hello/... at the top.

A file named "name,xxx" is stored as "name" with filetype &xxx, in the
InfoZip RISC OS extra field ("AC" / ARC0: load and exec address and
attributes), which SparkFS and InfoZip's RISC OS unzip both restore.
Files without a ,xxx suffix get a type from EXT_TYPES, or &FFD (Data).
Unix names are stored as they are: on RISC OS the unzipper swaps '.' and
'/', so "data/base.wz" unpacks as data.base/wz, which is the name UnixLib
programs use for "data/base.wz". Hidden files (.name) are left out.
From riscos-warzone2100 (tools/rozip.py).
"""
import os, re, struct, sys, time, zipfile

EXT_TYPES = {'.conf': 0xFFF, '.txt': 0xFFF, '.md': 0xFFF, '.html': 0xFAF, '.png': 0xB60}


def riscos_extra(filetype, mtime):
    # Centiseconds since 1900-01-01, the RISC OS time format.
    cs = int((mtime + 2208988800) * 100)
    load = 0xFFF00000 | (filetype << 8) | ((cs >> 32) & 0xFF)
    exe = cs & 0xFFFFFFFF
    attr = 0x33                      # owner and public read/write
    data = b'ARC0' + struct.pack('<4I', load, exe, attr, 0)
    return struct.pack('<2H', 0x4341, len(data)) + data


def add(zf, path):
    base = os.path.basename(path)
    m = re.match(r'^(.*),([0-9a-fA-F]{3})$', base)
    if m:
        name = os.path.join(os.path.dirname(path), m.group(1))
        ftype = int(m.group(2), 16)
    else:
        name = path
        ftype = EXT_TYPES.get(os.path.splitext(base)[1].lower(), 0xFFD)
    mtime = os.path.getmtime(path)
    zi = zipfile.ZipInfo(name.replace(os.sep, '/'), time.localtime(mtime)[:6])
    zi.compress_type = zipfile.ZIP_DEFLATED
    zi.external_attr = 0o644 << 16
    zi.extra = riscos_extra(ftype, mtime)
    with open(path, 'rb') as f:
        zf.writestr(zi, f.read(), compresslevel=9)


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    out = os.path.abspath(argv[0])
    args = argv[1:]
    if args[0] == '-C':
        os.chdir(args[1])
        args = args[2:]
    with zipfile.ZipFile(out, 'w') as zf:
        for top in args:
            if os.path.isfile(top):
                add(zf, top)
                continue
            for root, dirs, files in os.walk(top):
                dirs[:] = sorted(d for d in dirs if not d.startswith('.'))
                zi = zipfile.ZipInfo(root.replace(os.sep, '/') + '/')
                zi.external_attr = (0o40755 << 16) | 0x10
                zf.writestr(zi, b'')
                for f in sorted(x for x in files if not x.startswith('.')):
                    add(zf, os.path.join(root, f))


if __name__ == '__main__':
    main(sys.argv[1:])
