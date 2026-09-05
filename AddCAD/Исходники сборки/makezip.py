# -*- coding: utf-8 -*-
"""Упаковка дистрибутива AddCAD для переноса на другой компьютер."""
import os
import sys
import zipfile

SRC = sys.argv[1]   # папка с плагином
OUT = sys.argv[2]   # итоговый zip
# Имя корневой папки внутри архива. Установщик ищет именно AddCAD\install.ps1,
# поэтому оно не должно зависеть от того, как названа папка на диске.
ROOT = sys.argv[3] if len(sys.argv) > 3 else 'AddCAD'

count = 0
with zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(SRC):
        for f in files:
            full = os.path.join(root, f)
            rel = os.path.join(ROOT, os.path.relpath(full, SRC))
            z.write(full, rel)
            count += 1

print('архив:', OUT)
print('файлов:', count, '| размер:', os.path.getsize(OUT), 'байт')
