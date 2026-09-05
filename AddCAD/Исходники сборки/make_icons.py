# -*- coding: utf-8 -*-
"""Иконки ГеоРамки в формате BMP 32 бита - ровно как в рабочем MDS.cuix
(16x16 = 54 байта заголовка + 1024 байта пикселей = 1078 байт)."""
import os
import sys
import struct

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)

# --- палитра (BGRA) ---------------------------------------------------
PAPER = (246, 246, 244, 255)
INK = (28, 62, 110, 255)
STAMP = (208, 88, 24, 255)
DIGIT = (24, 24, 28, 255)
CLEAR = (0, 0, 0, 0)

FONT = {
    '0': ['111', '101', '101', '101', '111'],
    '1': ['010', '110', '010', '010', '111'],
    '2': ['111', '001', '111', '100', '111'],
    '3': ['111', '001', '111', '001', '111'],
    '4': ['101', '101', '111', '001', '001'],
}


class Img(object):
    def __init__(self, w, h):
        self.w = w
        self.h = h
        self.px = [[CLEAR for _ in range(w)] for _ in range(h)]

    def dot(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def rect_fill(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.dot(x, y, c)

    def rect_line(self, x0, y0, x1, y1, c):
        for x in range(x0, x1 + 1):
            self.dot(x, y0, c)
            self.dot(x, y1, c)
        for y in range(y0, y1 + 1):
            self.dot(x0, y, c)
            self.dot(x1, y, c)

    def glyph(self, ch, x, y, scale, c):
        for ry, row in enumerate(FONT.get(ch, [])):
            for rx, bit in enumerate(row):
                if bit == '1':
                    self.rect_fill(x + rx * scale, y + ry * scale,
                                   x + rx * scale + scale - 1,
                                   y + ry * scale + scale - 1, c)

    def bmp(self):
        """32-битный BI_RGB BMP, строки снизу вверх, порядок BGRA."""
        rows = b''
        for y in range(self.h - 1, -1, -1):
            for (r, g, b, a) in self.px[y]:
                rows += bytes((b, g, r, a))
        info = struct.pack('<IiiHHIIiiII', 40, self.w, self.h, 1, 32, 0,
                           len(rows), 2835, 2835, 0, 0)
        head = struct.pack('<2sIHHI', b'BM', 14 + 40 + len(rows), 0, 0, 54)
        return head + info + rows


def sheet_box(size, horizontal):
    if size == 32:
        return (1, 5, 30, 26) if horizontal else (5, 1, 26, 30)
    return (0, 2, 15, 13) if horizontal else (2, 0, 13, 15)


def draw(size, fmt, horizontal, stamp_only=False):
    im = Img(size, size)
    x0, y0, x1, y1 = sheet_box(size, horizontal)
    im.rect_fill(x0, y0, x1, y1, PAPER)
    im.rect_line(x0, y0, x1, y1, INK)
    if size == 32:
        im.rect_line(x0 + 2, y0 + 2, x1 - 2, y1 - 2, INK)
        sw, sh = (12, 6) if not stamp_only else (17, 10)
        sx1, sy1 = x1 - 3, y1 - 3
        im.rect_fill(sx1 - sw, sy1 - sh, sx1, sy1, STAMP)
        im.rect_line(sx1 - sw, sy1 - sh, sx1, sy1, INK)
        for k in range(1, 3):
            yy = sy1 - sh + k * (sh // 3)
            for xx in range(sx1 - sw, sx1 + 1):
                im.dot(xx, yy, INK)
        if not stamp_only:
            im.glyph(fmt, x0 + 4, y0 + 5, 2, DIGIT)
    else:
        sw, sh = (6, 3) if not stamp_only else (9, 5)
        sx1, sy1 = x1 - 1, y1 - 1
        im.rect_fill(sx1 - sw, sy1 - sh, sx1, sy1, STAMP)
        if not stamp_only:
            im.glyph(fmt, x0 + 2, y0 + 2, 2, DIGIT)
    return im


made = []
for fmt in '01234':
    for horiz, suf in ((True, 'gor'), (False, 'vert')):
        for size in (32, 16):
            name = 'A%s_%s_%d.bmp' % (fmt, suf, size)
            open(os.path.join(OUT, name), 'wb').write(
                draw(size, fmt, horiz).bmp())
            made.append(name)

for size in (32, 16):
    name = 'shtamp_%d.bmp' % size
    open(os.path.join(OUT, name), 'wb').write(
        draw(size, '3', True, stamp_only=True).bmp())
    made.append(name)

print('иконок:', len(made))
print('размер 16x16:', os.path.getsize(os.path.join(OUT, 'A3_gor_16.bmp')),
      'байт (в рабочем MDS.cuix - 1078)')
print('размер 32x32:', os.path.getsize(os.path.join(OUT, 'A3_gor_32.bmp')),
      'байт')
