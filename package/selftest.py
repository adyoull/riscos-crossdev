#!/usr/bin/env python3
"""Self-test for package/png2sprite.py (run by make check).

Writes PNGs using each of PNG's five row filters, converts them, and reads
the sprite file back: the header fields, every pixel and every mask bit.
"""
import os, struct, sys, tempfile, zlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import png2sprite

W, H = 37, 5          # 37: the mask needs two words a row, the last one partly used


def pixel(x, y):
    return ((x * 7) & 255, (y * 50) & 255, (x * y) & 255, 255 if (x + y) % 3 else 0)


def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    return a if pa <= pb and pa <= pc else b if pb <= pc else c


def write_png(path):
    raw, prev = b'', bytes(W * 4)
    for y in range(H):
        line = bytes(c for x in range(W) for c in pixel(x, y))
        f = y % 5                                 # filters 0..4, one a row
        out = bytearray()
        for i, v in enumerate(line):
            a = line[i - 4] if i >= 4 else 0
            b = prev[i]
            c = prev[i - 4] if i >= 4 else 0
            pred = [0, a, b, (a + b) // 2, paeth(a, b, c)][f]
            out.append((v - pred) & 255)
        raw += bytes([f]) + out
        prev = line

    def chunk(k, d):
        return struct.pack('>I', len(d)) + k + d + struct.pack('>I', zlib.crc32(k + d))
    with open(path, 'wb') as fh:
        fh.write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 6, 0, 0, 0))
                 + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))


def main():
    fails = []

    def check(cond, what):
        if not cond:
            fails.append(what)
            print('FAIL', what)

    with tempfile.TemporaryDirectory() as d:
        png, spr = os.path.join(d, 'p.png'), os.path.join(d, 'out,ff9')
        write_png(png)
        png2sprite.main(['png2sprite', spr, '!Test=' + png, 'two=' + png])
        data = open(spr, 'rb').read()
    n, first, free = struct.unpack('<3I', data[:12])
    check(n == 2 and first == 16 and free == len(data) + 4, 'the file header: count, first, free')
    p = first - 4
    size, name, wm1, hm1, fb, lb, img, mask, mode = struct.unpack('<I12s7I', data[p:p + 44])
    check(name.rstrip(b'\0') == b'!test', 'the name, lower case')
    check((wm1, hm1, fb, lb) == (W - 1, H - 1, 0, 31), 'width in words - 1, height - 1, first and last bit')
    check(mode == (6 << 27 | 90 << 14 | 90 << 1 | 1), 'the mode word: 32 bpp, 90 x 90 dpi')
    check(img == 44 and mask == 44 + W * H * 4, 'image after the header, mask after the image')
    check(size == mask + H * 2 * 4, 'the sprite size: header, image, a mask of 2 words a row')
    bad = 0
    for y in range(H):
        for x in range(W):
            r, g, b, a = pixel(x, y)
            word, = struct.unpack_from('<I', data, p + img + (y * W + x) * 4)
            m, = struct.unpack_from('<I', data, p + mask + y * 8 + (x // 32) * 4)
            if word != (r | g << 8 | b << 16) or bool(m >> (x % 32) & 1) != (a >= 128):
                bad += 1
        _, spare = struct.unpack_from('<2I', data, p + mask + y * 8)
        check(spare >> (W - 32) == 0, f'row {y}: mask bits past the width are clear')
    check(bad == 0, f'every pixel and mask bit, through all five PNG filters ({bad} wrong)')
    check(data[p + size + 4:p + size + 16].rstrip(b'\0') == b'two', 'the second sprite follows')
    print(f'png2sprite selftest: {"passed" if not fails else f"{len(fails)} failed"}')
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
