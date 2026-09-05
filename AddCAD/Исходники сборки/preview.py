# -*- coding: utf-8 -*-
"""Склейка иконок в один увеличенный лист для визуальной проверки."""
import os
import sys
import zlib
import struct

SRC = sys.argv[1]
DST = sys.argv[2]
SCALE = 6
BG = (60, 64, 72, 255)     # тёмный фон, как в AutoCAD


def read_png(path):
    data = open(path, 'rb').read()
    pos = 8
    w = h = None
    idat = b''
    while pos < len(data):
        ln = struct.unpack('>I', data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + ln]
        if tag == b'IHDR':
            w, h = struct.unpack('>II', body[:8])
        elif tag == b'IDAT':
            idat += body
        pos += 12 + ln
    raw = zlib.decompress(idat)
    stride = w * 4
    rows = []
    prev = bytearray(stride)
    p = 0
    for _ in range(h):
        ft = raw[p]
        p += 1
        line = bytearray(raw[p:p + stride])
        p += stride
        if ft == 1:
            for i in range(4, stride):
                line[i] = (line[i] + line[i - 4]) & 0xff
        elif ft == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xff
        elif ft == 3:
            for i in range(stride):
                a = line[i - 4] if i >= 4 else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xff
        elif ft == 4:
            for i in range(stride):
                a = line[i - 4] if i >= 4 else 0
                b = prev[i]
                c = prev[i - 4] if i >= 4 else 0
                pp = a + b - c
                pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xff
        rows.append([tuple(line[i:i + 4]) for i in range(0, stride, 4)])
        prev = line
    return w, h, rows


def over(fg, bg):
    a = fg[3] / 255.0
    return tuple(int(fg[i] * a + bg[i] * (1 - a)) for i in range(3)) + (255,)


names = [n for n in sorted(os.listdir(SRC)) if n.endswith('_32.png')]
cols = 6
rows_n = (len(names) + cols - 1) // cols
cell = 32 * SCALE + 8
W, H = cols * cell, rows_n * cell
canvas = [[BG for _ in range(W)] for _ in range(H)]

for idx, n in enumerate(names):
    w, h, px = read_png(os.path.join(SRC, n))
    cx = (idx % cols) * cell + 4
    cy = (idx // cols) * cell + 4
    for y in range(h):
        for x in range(w):
            c = over(px[y][x], BG)
            for dy in range(SCALE):
                for dx in range(SCALE):
                    canvas[cy + y * SCALE + dy][cx + x * SCALE + dx] = c

raw = b''
for row in canvas:
    raw += b'\x00'
    for (r, g, b, a) in row:
        raw += bytes((r, g, b, a))


def chunk(tag, data):
    body = tag + data
    return struct.pack('>I', len(data)) + body + struct.pack(
        '>I', zlib.crc32(body) & 0xffffffff)


out = (b'\x89PNG\r\n\x1a\n'
       + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 6, 0, 0, 0))
       + chunk(b'IDAT', zlib.compress(raw, 9))
       + chunk(b'IEND', b''))
open(DST, 'wb').write(out)
print('превью:', DST, W, 'x', H)
print('порядок:', ', '.join(n.replace('_32.png', '') for n in names))
