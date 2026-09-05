# Как собрать плагин для AutoCAD

Рецепт сборки плагина AutoCAD без Visual Studio и без .NET — на LISP + CUIX.
Проверен на AutoCAD 2025 (русский, профиль `ACAD-8101:419`) при сборке плагина
AddCAD (утилита «Рамки») 05.09.2026.

## 1. Структура bundle

Autodesk сам подхватывает любой каталог `*.bundle` из
`%APPDATA%\Autodesk\ApplicationPlugins\` — установщик как таковой не нужен,
достаточно скопировать папку.

```
AddCAD.bundle\
  PackageContents.xml
  Contents\
    AddCAD.cuix          лента и панели, одна на весь набор
    Ramki\               по подпапке на утилиту
      Ramki.lsp          команды
      Blocks\*.dwg       ресурсы
```

## 2. PackageContents.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<ApplicationPackage SchemaVersion="1.0" Name="AddCAD" AppVersion="1.0.0"
                    ProductCode="ID_<любой GUID>">
  <Components>
    <RuntimeRequirements OS="Win64" />
    <ComponentEntry ComponentName="MyPaths" ModuleName="./Contents"
                    AppDescription="Support Path" />
    <ComponentEntry ComponentName="MainUI" ModuleName="./Contents/X.cuix"
                    LoadOnAutoCADStartup="True" />
    <ComponentEntry ComponentName="L1" ModuleName="./Contents/X.lsp"
                    LoadOnAutoCADStartup="True" />
  </Components>
</ApplicationPackage>
```

`ComponentName="MyPaths"` с `AppDescription="Support Path"` — ключевая строка:
добавляет каталог в путь поиска вспомогательных файлов, после чего работают
`findfile` и `(load "X.lsp")`. Отдельная запись нужна для каждой подпапки
с ресурсами.

## 3. Доверенные местоположения — обязательный шаг

При `SECURELOAD = 1` (значение по умолчанию) AutoCAD откажется грузить LISP
из недоверенного каталога. Путь надо дописать в переменную `TRUSTEDPATHS`:

```
HKCU\Software\Autodesk\AutoCAD\R25.0\<ACAD-код>\Profiles\<профиль>\Variables
  TRUSTEDPATHS   ...;%APPDATA%\...\X.bundle\Contents\...
```

Суффикс `\...` означает «включая подпапки». Правку делать **только при закрытом
AutoCAD** — при выходе он перезаписывает свою ветку реестра целиком.
Без этого шага пользователь получает окно «всегда загружать» на каждом старте.

## 4. Формат CUIX

CUIX — это OPC-пакет, то есть обычный zip:

```
[Content_Types].xml     Default-записи для cui / bmp / xml / rels
_rels/.rels             <Relationship Type="CUI"   Target="/MenuGroup.cui" Id="R…" />
                        <Relationship Type="Image" Target="/icon.bmp"      Id="R…" />
Menu_Package_Info.xml   манифест частей — ОБЯЗАТЕЛЕН, см. ниже
<20 файлов *.cui>       полный набор корневых секций,
                        неиспользуемые — пустой самозакрывающийся тег
<иконки *.bmp>          лежат в корне пакета, без подпапок
```

**`Menu_Package_Info.xml` — самая важная и наименее очевидная часть.**
Без него AutoCAD загружает пакет лишь частично: вкладка ленты может
появиться, но панель будет пустой, а иконки не попадут в `.mnr`.
Формат — плоский список всех частей:

```xml
<?xml version="1.0" encoding="utf-8"?>
<MenuPackageParts>
  <PartData PartData_Name="/Header.cui" PartData_Modified="2026-09-05T13:40:00+03:00" />
  …все 20 .cui…
  <PartData PartData_Name="/VirtualMNRRoot" PartData_Modified="…" />
  <PartData PartData_Name="/Menu_Package_Info.xml" PartData_Modified="…" />
  …каждый .bmp отдельной строкой…
</MenuPackageParts>
```

`/VirtualMNRRoot` — виртуальная запись, отдельного файла в архиве ей не нужно;
именно она отвечает за растровые ресурсы. Перечислять надо **все** части,
включая сам `Menu_Package_Info.xml`. В `_rels/.rels` его добавлять не нужно.

Проверить чужой CUIX на эталон: `custom.cuix` в
`%APPDATA%\Autodesk\AutoCAD <версия>\R<..>\<язык>\Support\` — штатный пустой
файл адаптации от Autodesk, минимальный корректный пример (3 части).

**Иконки — BMP, не PNG.** Рабочий формат, подтверждённый обоими образцами:
BMP 32 бита BI_RGB, строки снизу вверх, порядок каналов BGRA,
16×16 = ровно 1078 байт (54 заголовка + 1024 пикселей), 32×32 = 4150 байт.
Пишется из Python без сторонних библиотек через `struct.pack`:
`<2sIHHI` для файлового заголовка и `<IiiHHIIiiII` для BITMAPINFOHEADER.
PNG формально допустим, но с ним панель ленты
у меня осталась пустой — не тратить на него время.

Обязательные секции: Header, WorkspaceRoot, MenuGroup, AcceleratorRoot,
OverrideRoot, MouseButtonRoot, PopMenuRoot, ToolbarRoot, DoubleClickRoot,
QuickPropertiesRoot, RolloverTooltipRoot, RibbonRoot, QuickAccessToolbarRoot,
ToolPanelRoot, PanelSetRoot, ScreenMenuRoot, ImageMenuRoot, TabletMenuRoot,
DigitizerButtonRoot, LSPFiles.

Внутри всё в UTF-8, у каждого корня атрибуты
`xmlns:xsd`/`xmlns:xsi` из стандартных схем W3C.

### Команда

```xml
<MenuMacro UID="MMU_GR_001">
  <Macro type="Any">
    <Name xlate="true" UID="XLS_GR_001">Рамка</Name>
    <Command>^C^C^P(if (not c:ARAMKA)(load "Ramki.lsp"));^PARAMKA;</Command>
    <SmallImage Name="icon_16.bmp" /><LargeImage Name="icon_32.bmp" />
  </Macro>
</MenuMacro>
```

Иконка задаётся в макросе, а не в кнопке; кнопка ссылается на макрос
через `MenuMacroID`.

### Лента

`RibbonPanelSource` → `RibbonRow` → `RibbonCommandButton`
(`ButtonStyle`: `LargeWithText` / `SmallWithText` / `SmallWithoutText`).
`RibbonRowPanel` группирует несколько рядов мелких кнопок по вертикали,
`RibbonPanelBreak` разбивает панель на строки, `RibbonSeparator` —
разделитель со `SeparatorStyle="Line"`.

Вкладка: `RibbonTabSource` с `WorkspaceBehavior="AddTabOnly"`. Она добавляется
в рабочее пространство сама, но **только при первой загрузке группы** —
дальше запись живёт в `Profile.aws` и правится отдельно, см. раздел 7.

## 4a. Чтение и правка DWG снаружи

Прочитать содержимое DWG из PowerShell можно через запущенный AutoCAD:

```powershell
$acad = [Runtime.InteropServices.Marshal]::GetActiveObject('AutoCAD.Application')
$dbx  = $acad.GetInterfaceObject('ObjectDBX.AxDbDocument.25')   # 25 = AutoCAD 2025
$dbx.Open($path)
foreach ($o in $dbx.ModelSpace) { $o.ObjectName; $o.TextString; $o.StartPoint }
```

Чтение работает надёжно и окон не открывает. **А вот записывать (`SaveAs`)
этим способом нельзя** — проверено 05.09.2026: AutoCAD намертво повис
(`Responding = False`), а после снятия процесса выдал ошибку модуля отчёта
CER. Внешний COM дёргает главный поток приложения.

Если DWG надо именно править — делать это изнутри AutoCAD: тот же ObjectDBX,
но из AutoLISP (`vla-GetInterfaceObject` → `vla-Open` → `vla-SaveAs`).
Так работает надёжно, проверено на 11 файлах.

**`vla-SaveAs` без второго аргумента меняет версию DWG** на формат по
умолчанию текущего AutoCAD: рамки AddCAD уехали с AC1021 (2007) на
AC1032 (2018), заодно похудев с 70 КБ до 19,6 КБ. Файл перестаёт
открываться в AutoCAD старше 2018. Если версия важна — передавать
`AcSaveAsType` вторым аргументом.

Ещё безопаснее вообще не трогать файлы, а дочерчивать нужное в чертеже
после вставки блока — см. `gr:addlabels` в AddCAD.

## 5. Подводные камни LISP

- Файл сохранять в **CP1251**, а не UTF-8 — надёжнее для русского AutoCAD.
- В `(command "_.-INSERT" путь …)` путь брать в кавычки: `(strcat "\"" f "\"")`.
  Иначе пробел внутри строки будет воспринят как Enter.
- Вставка DWG: `-INSERT` → точка → X-масштаб → Y-масштаб → поворот.
  Схема «вставить → EXPLODE → -PURGE Blocks» не оставляет мусора в чертеже.
- Два десятка однотипных команд удобно объявить циклом:
  `(eval (list 'defun (read (strcat "c:" имя)) '() …))`.

## 6. Если вкладка появилась, а панель пустая

Симптом: вкладка ленты на месте, заголовок панели виден, кнопок нет.
Или вкладка вообще пропала. Что проверять, по убыванию вероятности:

1. **Нет `Menu_Package_Info.xml`** — самая частая причина, см. выше.
   Диагностика: AutoCAD копирует CUIX в
   `%APPDATA%\Autodesk\AutoCAD <версия>\R<..>\<язык>\Support\` и компилирует
   рядом `<имя>.mnr`. Если `.mnr` весит **6 байт** — растровые ресурсы
   не подхватились. Для сравнения: у адаптации с иконками он сотни килобайт
   (у рабочей чужой адаптации — сотни килобайт). Шесть байт нормальны
   только для адаптации вообще
   без иконок, как штатный `custom.mnr`.
2. **Формат иконок** — BMP, не PNG.
3. **Префиксы UID.** AutoCAD везде использует `MMU_` (MenuMacro),
   `RBNU_` (ribbon), `XLS_` (строка), `TBB_` (кнопка панели),
   `TBU_` (панель инструментов). Произвольные лучше не выдумывать.
4. `MenuMacroID` кнопки обязан совпадать с `UID` существующего `MenuMacro` —
   висячая ссылка не даёт ошибки, кнопка молча пропускается.
5. **Кэш адаптации.** AutoCAD работает не с оригиналом в bundle, а со своей
   копией в `…\<язык>\Support\`. При отладке — закрыть AutoCAD и удалить
   оттуда `<имя>.cuix`, `.bak`, `.bk0`, `<имя>.mnr`, `<имя>_light.mnr`,
   чтобы он загрузил всё заново. Иначе правки могут не подхватиться,
   а вкладка — не вернуться в рабочее пространство.
6. Держать `UID` вкладки (`RibbonTabSource`) **стабильным** между версиями:
   рабочее пространство запоминает его в `Profile.aws`, и после смены UID
   вкладка пропадает — старая ссылка мертва, новая не добавляется.
7. **`WorkspaceBehavior="AddTabOnly"` срабатывает только при первой загрузке
   группы.** Если группа уже загружалась, вкладка в рабочее пространство
   больше не добавится сама, сколько CUIX ни правь.

## 7. Как вручную прописать вкладку в рабочее пространство

Рабочее пространство лежит в
`…\<язык>\support\profiles\<имя профиля>\Profile.aws` — это XML, несмотря
на расширение. Вкладки перечислены внутри `<WSRibbonRoot>`; дописать свою
перед закрывающим тегом:

```xml
<WSRibbonTabSourceReference MenuGroup="GEORAMKI" TabId="RBNU_GR_TAB"
                            Show="true" IsActive="false" UID="WSRU_GR_00001">
  <ModifiedRev MajorVersion="25" MinorVersion="0" UserVersion="1"/>
  <WSRibbonPanelSourceReference PanelId="RBNU_GR_PANEL" Orientation="Docked"
      Show="true" xval="0" yval="0" FloatingGroup="0" FloatingOrder="0"
      FloatingOrientation="Vertical" PanelResizeOrder="100"/>
</WSRibbonTabSourceReference>
```

`MenuGroup` — имя из `MenuGroup.cui`, `TabId` — UID из `RibbonTabSource`,
`PanelId` — UID из `RibbonPanelSource`. **Только при закрытом AutoCAD**:
при выходе он перезаписывает `Profile.aws` целиком.

Скрипт для этого — `add_tab_to_ws.py` в исходниках ГеоРамок.

Побочное следствие: пока вкладки нет в рабочем пространстве, панель
не строится, иконки не нужны — и `.mnr` остаётся почти пустым.
То есть маленький `.mnr` бывает не причиной, а симптомом.

## 8. Проверка перед установкой

- Баланс скобок LISP — своим скриптом, с учётом строк и комментариев.
- Валидность каждого XML в CUIX — `xml.dom.minidom.parseString`.
- Сквозная сверка: все `MenuMacroID` разрешаются в объявленные `MenuMacro`,
  все `SmallImage`/`LargeImage` присутствуют в пакете.
- Лучший способ подобрать формат — распаковать чужой рабочий CUIX
  (`MDS.cuix`, `menu GEO 0_15.cuix`) и копировать его структуру буквально.

Рабочий образец готового плагина, собранного по этому рецепту, лежит в
`%APPDATA%\Autodesk\ApplicationPlugins\AddCAD.bundle`.
Второй живой пример для сверки схемы — любой рабочий `*.bundle`
из той же папки.
См. также [[addcad-plugin]] и [[acad-environment]].
