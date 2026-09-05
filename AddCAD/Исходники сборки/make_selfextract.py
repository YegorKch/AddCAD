# -*- coding: utf-8 -*-
"""Однофайловый установщик: .bat с вшитым в base64 дистрибутивом.

Работает на голой Windows - нужен только PowerShell, который есть всегда.
Заголовок пишется в CP1251 (под chcp 1251), payload - чистый ASCII.
"""
import base64
import os
import sys

ZIP = sys.argv[1]
OUT = sys.argv[2]

HEAD = r'''@echo off
chcp 1251 >nul
setlocal
title AddCAD - установка

echo ------------------------------------------
echo   AddCAD 1.0.0 - установка
echo ------------------------------------------
echo.

tasklist /FI "IMAGENAME eq acad.exe" 2>nul | find /I "acad.exe" >nul
if not errorlevel 1 (
    echo AutoCAD запущен. Закройте его и запустите установку заново.
    echo.
    pause
    exit /b 1
)

set "TMPDIR=%TEMP%\AddCAD_setup"
if exist "%TMPDIR%" rd /s /q "%TMPDIR%"
mkdir "%TMPDIR%"

echo Распаковка...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$s=Get-Content -LiteralPath '%~f0'; $i=[array]::IndexOf($s,'#PAYLOAD#');" ^
 "$b=($s[($i+1)..($s.Count-1)]) -join '';" ^
 "[IO.File]::WriteAllBytes('%TMPDIR%\p.zip',[Convert]::FromBase64String($b));" ^
 "Add-Type -A System.IO.Compression.FileSystem;" ^
 "[IO.Compression.ZipFile]::ExtractToDirectory('%TMPDIR%\p.zip','%TMPDIR%')"

if not exist "%TMPDIR%\AddCAD\install.ps1" (
    echo ОШИБКА: распаковка не удалась.
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%TMPDIR%\AddCAD\install.ps1"

rd /s /q "%TMPDIR%"
exit /b 0

#PAYLOAD#
'''

data = base64.b64encode(open(ZIP, 'rb').read()).decode('ascii')
lines = [data[i:i + 76] for i in range(0, len(data), 76)]

with open(OUT, 'wb') as f:
    f.write(HEAD.replace('\n', '\r\n').encode('cp1251'))
    f.write(('\r\n'.join(lines) + '\r\n').encode('ascii'))

print('установщик:', OUT)
print('размер:', os.path.getsize(OUT), 'байт',
      '(исходный zip %d)' % os.path.getsize(ZIP))
print('строк payload:', len(lines))
