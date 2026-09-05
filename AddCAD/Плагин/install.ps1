# Установка плагина ГеоРамки
# Копирует bundle в ApplicationPlugins и прописывает его
# в доверенные местоположения всех найденных профилей AutoCAD.

$ErrorActionPreference = 'Stop'

Write-Host '------------------------------------------'
Write-Host '  AddCAD - установка'
Write-Host '------------------------------------------'

$acad = Get-Process -Name acad -ErrorAction SilentlyContinue
if ($acad) {
    Write-Host ''
    Write-Host 'AutoCAD запущен. Закройте его и запустите установку заново.' -ForegroundColor Red
    Write-Host ''
    Read-Host 'Enter для выхода'
    exit 1
}

$src = Join-Path $PSScriptRoot 'AddCAD.bundle'
if (-not (Test-Path $src)) {
    Write-Host "Не найдена папка AddCAD.bundle рядом с установщиком." -ForegroundColor Red
    Read-Host 'Enter для выхода'
    exit 1
}

$dst = Join-Path $env:APPDATA 'Autodesk\ApplicationPlugins\AddCAD.bundle'

if (Test-Path $dst) {
    Write-Host 'Удаляю предыдущую версию...'
    Remove-Item -Recurse -Force $dst
}

$parent = Split-Path $dst -Parent
if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force $parent | Out-Null }

Copy-Item -Recurse $src $dst
Write-Host "Скопировано в: $dst" -ForegroundColor Green

# --- доверенные местоположения ---------------------------------------
# Без этого при SECURELOAD=1 AutoCAD откажется грузить LISP.

$trust = Join-Path $dst 'Contents\...'
$done = 0

$root = 'HKCU:\Software\Autodesk\AutoCAD'
if (Test-Path $root) {
    foreach ($ver in Get-ChildItem $root -ErrorAction SilentlyContinue) {
        foreach ($prod in Get-ChildItem $ver.PSPath -ErrorAction SilentlyContinue) {
            $profs = Join-Path $prod.PSPath 'Profiles'
            if (-not (Test-Path $profs)) { continue }
            foreach ($prof in Get-ChildItem $profs -ErrorAction SilentlyContinue) {
                $vars = Join-Path $prof.PSPath 'Variables'
                if (-not (Test-Path $vars)) { continue }
                $cur = (Get-ItemProperty -Path $vars -Name TRUSTEDPATHS -ErrorAction SilentlyContinue).TRUSTEDPATHS
                if ($null -eq $cur) { $cur = '' }
                if ($cur -like '*AddCAD.bundle*') { continue }
                if ($cur.Trim() -eq '') { $new = $trust }
                else { $new = $cur.TrimEnd(';') + ';' + $trust }
                Set-ItemProperty -Path $vars -Name TRUSTEDPATHS -Value $new
                $done = $done + 1
            }
        }
    }
}

Write-Host "Профилей AutoCAD обновлено: $done"
Write-Host ''
Write-Host 'Готово. Запустите AutoCAD - появится вкладка ленты "AddCAD".' -ForegroundColor Green
Write-Host 'Команды: АРАМКА, АШТАМП, быстрые Р3Г, Р4В и т.п.'
Write-Host ''
Read-Host 'Enter для выхода'
