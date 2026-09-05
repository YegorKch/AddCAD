@echo off
chcp 1251 >nul
set "DEST=%APPDATA%\Autodesk\ApplicationPlugins\AddCAD.bundle"

echo ------------------------------------------
echo   AddCAD - удаление
echo ------------------------------------------

if exist "%DEST%" (
    echo Удаляю: %DEST%
    rd /s /q "%DEST%"
    echo.
    echo Готово. Перезапустите AutoCAD.
    echo Путь плагина останется в доверенных местоположениях -
    echo это безвредно, но при желании его можно убрать
    echo командой ДОВПУТИ ^(TRUSTEDPATHS^) в AutoCAD.
) else (
    echo.
    echo Плагин не найден в ApplicationPlugins.
)

echo.
pause
