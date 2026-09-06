@echo off
chcp 1251 >nul
setlocal
title AddCAD - удаление

echo ------------------------------------------
echo   AddCAD - удаление
echo ------------------------------------------
echo.

tasklist /FI "IMAGENAME eq acad.exe" 2>nul | find /I "acad.exe" >nul
if not errorlevel 1 (
    echo AutoCAD запущен. Закройте его и запустите удаление заново.
    echo.
    pause
    exit /b 1
)

set "DEST=%APPDATA%\Autodesk\ApplicationPlugins\AddCAD.bundle"

if not exist "%DEST%" (
    echo Плагин не найден в ApplicationPlugins - удалять нечего.
    echo.
    pause
    exit /b 0
)

echo Удаляю: %DEST%
rd /s /q "%DEST%"

echo Убираю доверенный путь из профилей AutoCAD...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$n=0; $root='HKCU:\Software\Autodesk\AutoCAD';" ^
 "if (Test-Path $root) { foreach ($v in Get-ChildItem $root -EA 0) {" ^
 " foreach ($p in Get-ChildItem $v.PSPath -EA 0) {" ^
 "  $pr=Join-Path $p.PSPath 'Profiles'; if (-not (Test-Path $pr)) { continue };" ^
 "  foreach ($q in Get-ChildItem $pr -EA 0) {" ^
 "   $vr=Join-Path $q.PSPath 'Variables'; if (-not (Test-Path $vr)) { continue };" ^
 "   $c=(Get-ItemProperty -Path $vr -Name TRUSTEDPATHS -EA 0).TRUSTEDPATHS;" ^
 "   if ($null -eq $c -or $c -notlike '*AddCAD.bundle*') { continue };" ^
 "   $k=@($c -split ';' ^| Where-Object { $_ -and ($_ -notlike '*AddCAD.bundle*') });" ^
 "   Set-ItemProperty -Path $vr -Name TRUSTEDPATHS -Value ($k -join ';'); $n++ } } } };" ^
 "Write-Host ('  профилей вычищено: ' + $n)"

echo.
echo Готово. AddCAD удалён полностью.
echo Чертежи не затронуты: вставленные рамки - обычные линии и текст,
echo они останутся и без плагина.
echo.
pause
