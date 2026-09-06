# Установка плагина AddCAD
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

# --- обход профилей AutoCAD в реестре ---------------------------------
# Путь установки AutoCAD не нужен: профили лежат в HKCU, а плагины -
# в папке профиля Windows. Здесь только перебор, что делать с найденным
# TRUSTEDPATHS - решает переданный блок.

function Each-Profile([scriptblock] $do) {
    $count = 0
    $root = 'HKCU:\Software\Autodesk\AutoCAD'
    if (Test-Path $root) {
        foreach ($ver in Get-ChildItem $root -ErrorAction SilentlyContinue) {
            foreach ($prod in Get-ChildItem $ver.PSPath -ErrorAction SilentlyContinue) {
                $profs = Join-Path $prod.PSPath 'Profiles'
                if (-not (Test-Path $profs)) { continue }
                foreach ($prof in Get-ChildItem $profs -ErrorAction SilentlyContinue) {
                    if (-not (Test-Path (Join-Path $prof.PSPath 'Variables'))) { continue }
                    $count++
                    & $do $prof.PSPath
                }
            }
        }
    }
    return $count
}

# Путь поиска вспомогательных файлов (значение ACAD в ветке General).
# Нужен ради картинок ленты: их AutoCAD ищет как файлы по этому списку,
# а объявленный в PackageContents.xml "Support Path" в список не попадает -
# проверено, там нет ни нашей папки, ни папок других плагинов.
# Пишем аккуратно: только дописываем своё в конец, чужого не трогаем.

function Add-SearchPath($profPath, $dir) {
    $gen = Join-Path $profPath 'General'
    if (-not (Test-Path $gen)) { return $false }
    $cur = (Get-ItemProperty -Path $gen -Name ACAD -ErrorAction SilentlyContinue).ACAD
    if ($null -eq $cur) { $cur = '' }
    if ($cur -like "*$dir*") { return $false }
    $new = if ($cur.Trim() -eq '') { $dir } else { $cur.TrimEnd(';') + ';' + $dir }
    Set-ItemProperty -Path $gen -Name ACAD -Value $new
    return $true
}

function Remove-SearchPath($profPath, $dir) {
    $gen = Join-Path $profPath 'General'
    if (-not (Test-Path $gen)) { return $false }
    $cur = (Get-ItemProperty -Path $gen -Name ACAD -ErrorAction SilentlyContinue).ACAD
    if ($null -eq $cur -or $cur -notlike "*$dir*") { return $false }
    $keep = @($cur -split ';' | Where-Object { $_ -and ($_ -ne $dir) })
    Set-ItemProperty -Path $gen -Name ACAD -Value ($keep -join ';')
    return $true
}

# --- удаление ----------------------------------------------------------
# Тот же файл и ставит, и удаляет: искать отдельный деинсталлятор
# внутри %APPDATA% пользователю неоткуда.

if (Test-Path $dst) {
    Write-Host ''
    Write-Host 'AddCAD уже установлен.' -ForegroundColor Yellow
    Write-Host '  [Enter] или [1] - переустановить, обновить до этой версии'
    Write-Host '  [2]            - удалить AddCAD с компьютера'
    Write-Host '  [3]            - выйти, ничего не меняя'
    # Выбор цифрами: буква зависела бы от раскладки клавиатуры,
    # а невидимый BOM во введённой строке ломал сравнение.
    $ans = (Read-Host 'Выбор') -replace '[^0-9]', ''

    if ($ans -eq '3') {
        Write-Host 'Ничего не изменено.'
        Read-Host 'Enter для выхода'
        exit 0
    }

    if ($ans -eq '2') {
        Remove-Item -Recurse -Force $dst
        Write-Host "Удалена папка: $dst" -ForegroundColor Green

        # чистим за собой в профилях: доверенный путь и путь поиска
        $cleaned = 0
        $unpathed = 0
        $iconDir = Join-Path $dst 'Contents'
        $n = Each-Profile {
            param($prof)
            $vars = Join-Path $prof 'Variables'
            $cur = (Get-ItemProperty -Path $vars -Name TRUSTEDPATHS -ErrorAction SilentlyContinue).TRUSTEDPATHS
            if ($null -ne $cur -and $cur -like '*AddCAD.bundle*') {
                $keep = @($cur -split ';' | Where-Object { $_ -and ($_ -notlike '*AddCAD.bundle*') })
                Set-ItemProperty -Path $vars -Name TRUSTEDPATHS -Value ($keep -join ';')
                $script:cleaned++
            }
            if (Remove-SearchPath $prof $iconDir) { $script:unpathed++ }
        }
        Write-Host "Профилей обработано: $n (доверенный путь убран: $cleaned, путь поиска: $unpathed)"
        Write-Host ''
        Write-Host 'Готово. AddCAD удалён полностью.' -ForegroundColor Green
        Write-Host 'Чертежи не затронуты: вставленные рамки - обычные линии'
        Write-Host 'и текст, они останутся и без плагина.'
        Write-Host ''
        Read-Host 'Enter для выхода'
        exit 0
    }

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
# Считаем отдельно: сколько профилей нашли, скольким дописали путь
# и сколько уже были настроены. Иначе повторная установка выглядит как
# провал: путь на месте, дописывать нечего, счётчик ноль.
$added = 0
$already = 0
$pathed = 0
$iconDir = Join-Path $dst 'Contents'

$found = Each-Profile {
    param($prof)
    $vars = Join-Path $prof 'Variables'
    $cur = (Get-ItemProperty -Path $vars -Name TRUSTEDPATHS -ErrorAction SilentlyContinue).TRUSTEDPATHS
    if ($null -eq $cur) { $cur = '' }
    if ($cur -like '*AddCAD.bundle*') {
        $script:already++
    } else {
        if ($cur.Trim() -eq '') { $new = $trust }
        else { $new = $cur.TrimEnd(';') + ';' + $trust }
        Set-ItemProperty -Path $vars -Name TRUSTEDPATHS -Value $new
        $script:added++
    }
    # папка плагина в пути поиска - иначе лента не найдёт свои картинки
    if (Add-SearchPath $prof $iconDir) { $script:pathed++ }
}

if ($found -gt 0) {
    $msg = "Профилей AutoCAD найдено: $found"
    if ($added -gt 0)   { $msg = $msg + ", доверенный путь прописан: $added" }
    if ($already -gt 0) { $msg = $msg + ", уже был настроен: $already" }
    if ($pathed -gt 0)  { $msg = $msg + ", путь поиска добавлен: $pathed" }
    Write-Host $msg -ForegroundColor Green
} else {
    Write-Host ''
    Write-Host 'Профили AutoCAD в реестре не найдены.' -ForegroundColor Yellow
    Write-Host 'Плагин скопирован и подхватится в любом случае - папка плагинов'
    Write-Host 'не зависит от того, куда установлен AutoCAD. Но доверенный путь'
    Write-Host 'прописать было некуда: похоже, AutoCAD ещё ни разу не запускали'
    Write-Host 'под этой учётной записью Windows. Запустите его, закройте'
    Write-Host 'и прогоните установку ещё раз - иначе он спросит разрешение'
    Write-Host 'на загрузку LISP.'
}
Write-Host ''
Write-Host 'Готово. Запустите AutoCAD - появится вкладка ленты "AddCAD".' -ForegroundColor Green
Write-Host 'Команды: АРАМКА, АШТАМП, быстрые Р3Г, Р4В и т.п.'
Write-Host ''
Read-Host 'Enter для выхода'
