# -*- coding: utf-8 -*-
"""Сборка GeoRamki.cuix.

Формат скопирован с двух заведомо рабочих файлов адаптации на этой машине:
MDS.cuix (MDSTools) и menu GEO 0_15.cuix. Отсюда - BMP-иконки и UID
со стандартными префиксами MMU_/RBNU_/XLS_/TBB_.
"""
import os
import sys
import zipfile

ICONS = sys.argv[1]
OUT = sys.argv[2]

GROUP = 'ADDCAD'
DISPLAY = 'AddCAD'
PANEL = 'Рамки'   # панель внутри вкладки; дальше их станет больше

HDR = ('<?xml version="1.0"?>\n'
       '<!-- Создано автоматически. Правьте через НПИ (CUI) в AutoCAD. -->\n')
NS = ('xmlns:xsd="http://www.w3.org/2001/XMLSchema" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"')
REV = '<ModifiedRev MajorVersion="25" MinorVersion="1" UserVersion="1" />'


def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def cmd(name):
    return '^C^C^P(if (not c:%s)(load "Ramki.lsp"));^P%s;' % (name, name)


# --- макросы ----------------------------------------------------------
# (uid, подпись в списке, команда, подсказка, база имени иконки)
macros = []
FMT = {'0': 'А0', '1': 'А1', '2': 'А2', '3': 'А3', '4': 'А4'}
n = 0
for f in '01234':
    for suf, ru, lat in (('gor', 'горизонтально', 'G'),
                         ('vert', 'вертикально', 'V')):
        n += 1
        macros.append(('MMU_GR_%03d' % n,
                       'Формат %s (%s)' % (FMT[f], ru),
                       'R%s%s' % (f, lat),
                       'Рамка %s, %s' % (FMT[f], ru),
                       'A%s_%s' % (f, suf)))
n += 1
MAC_SHTAMP = 'MMU_GR_%03d' % n
macros.append((MAC_SHTAMP, 'Штамп', 'ASHTAMP',
               'Вставка штампа на слой "Штамп"', 'shtamp'))
n += 1
MAC_RAMKA = 'MMU_GR_%03d' % n
macros.append((MAC_RAMKA, 'Рамка (выбор формата)', 'ARAMKA',
               'Выбор формата, ориентации и масштаба', 'A3_gor'))
n += 1
MAC_SCALE = 'MMU_GR_%03d' % n
macros.append((MAC_SCALE, 'Масштаб', 'ASCALE',
               'Масштаб вставки рамок по умолчанию', 'A3_gor'))

FORMAT_MACROS = [m for m in macros if m[0] not in
                 (MAC_SHTAMP, MAC_RAMKA, MAC_SCALE)]

# --- MenuGroup.cui ----------------------------------------------------
mg = [HDR, '<MenuGroup %s Name="%s" DisplayName="%s">\n' % (NS, GROUP, DISPLAY),
      '  <MacroGroup Name="%s">\n' % DISPLAY]
for i, (uid, label, c, tip, icon) in enumerate(macros):
    mg.append(
        '    <MenuMacro UID="%s">\n'
        '      <Macro type="Any">\n'
        '        <Revision MajorVersion="16" MinorVersion="2" UserVersion="1" />\n'
        '        %s\n'
        '        <Name xlate="true" UID="XLS_GR_N%03d">%s</Name>\n'
        '        <Command>%s</Command>\n'
        '        <HelpString xlate="true" UID="XLS_GR_H%03d">%s</HelpString>\n'
        '        <SmallImage Name="%s_16.bmp" />\n'
        '        <LargeImage Name="%s_32.bmp" />\n'
        '      </Macro>\n'
        '    </MenuMacro>\n'
        % (uid, REV, i, esc(label), esc(cmd(c)), i, esc(tip), icon, icon))
mg.append('  </MacroGroup>\n</MenuGroup>\n')
MENUGROUP = ''.join(mg)

# --- RibbonRoot.cui ---------------------------------------------------
_uid = [0]


def nid(prefix):
    _uid[0] += 1
    return '%s_GR_%03d' % (prefix, _uid[0])


def rbtn(macro_uid, style, tip):
    return ('          <RibbonCommandButton UID="%s" '
            'Id="AcRibbonCommandButton" Text="" ButtonStyle="%s" '
            'MenuMacroID="%s" KeyTip="">\n'
            '            <TooltipTitle xlate="true" UID="%s">%s</TooltipTitle>\n'
            '            %s\n'
            '          </RibbonCommandButton>\n'
            % (nid('RBNU'), style, macro_uid, nid('XLS'), esc(tip), REV))


rb = [HDR, '<RibbonRoot>\n', '  <RibbonPanelSourceCollection %s>\n' % NS,
      '    <RibbonPanelSource UID="RBNU_GR_PANEL" Text="%s" '
      'HiddenInEditor="false">\n' % PANEL,
      '      %s\n' % REV,
      '      <Name xlate="true" UID="XLS_GR_PANEL">%s</Name>\n' % PANEL,
      '      <RibbonRow UID="RBNU_GR_ROW1">\n',
      '        %s\n' % REV]

# выпадающий список форматов - как "Рамка и штамп" в menuGEO
rb.append('        <RibbonSplitButton UID="RBNU_GR_SPLIT" '
          'Id="AcRibbonSplitButton" Text="Рамка и штамп" '
          'SmallImage="A3_gor_16.bmp" LargeImage="A3_gor_32.bmp" '
          'Behavior="DropDownNoFollow" ListStyle="IconText" '
          'ButtonStyle="LargeWithText" Grouping="false">\n'
          '          %s\n' % REV)
for uid, label, c, tip, icon in FORMAT_MACROS:
    rb.append(rbtn(uid, 'SmallWithoutText', label))
rb.append(rbtn(MAC_SHTAMP, 'SmallWithoutText', 'Штамп'))
rb.append('        </RibbonSplitButton>\n')

rb.append('        <RibbonSeparator UID="RBNU_GR_SEP" '
          'Id="AcRibbonSeparator" SeparatorStyle="Line" />\n')

# рядом - две обычные большие кнопки, без вложенных рядов
rb.append(rbtn(MAC_RAMKA, 'LargeWithText', 'Рамка с выбором формата'))
rb.append(rbtn(MAC_SCALE, 'LargeWithText', 'Масштаб вставки'))

rb.append('      </RibbonRow>\n')
rb.append('    </RibbonPanelSource>\n  </RibbonPanelSourceCollection>\n')
rb.append('  <RibbonTabSourceCollection %s>\n' % NS)
rb.append('    <RibbonTabSource Text="%s" UID="RBNU_GR_TAB" '
          'WorkspaceBehavior="AddTabOnly">\n      %s\n'
          '      <Name xlate="true" UID="XLS_GR_TAB">%s</Name>\n'
          '      <Alias>ADDCAD_TAB</Alias>\n'
          '      <RibbonPanelSourceReference UID="RBNU_GR_PREF" '
          'PanelId="RBNU_GR_PANEL" ResizeStyle="NoCollapse">\n'
          '        %s\n      </RibbonPanelSourceReference>\n'
          '    </RibbonTabSource>\n' % (DISPLAY, REV, DISPLAY, REV))
rb.append('  </RibbonTabSourceCollection>\n</RibbonRoot>\n')
RIBBON = ''.join(rb)

# --- ToolbarRoot.cui --------------------------------------------------
tb = [HDR, '<ToolbarRoot %s>\n' % NS,
      '  <Toolbar ToolbarOrient="floating" ToolbarVisible="hide" '
      'xval="250" yval="250" rows="1" UID="TBU_GR_001">\n    %s\n'
      '    <Alias>ADDCAD_TB</Alias>\n'
      '    <Name xlate="true" UID="XLS_GR_TB">%s</Name>\n' % (REV, DISPLAY)]
for i, (uid, label, c, tip, icon) in enumerate(macros):
    tb.append('    <ToolbarButton IsSeparator="false" UID="TBB_GR_%03d" '
              'MenuMacroID="%s">\n      %s\n    </ToolbarButton>\n'
              % (i + 1, uid, REV))
tb.append('  </Toolbar>\n</ToolbarRoot>\n')
TOOLBAR = ''.join(tb)


def empty(tag):
    return HDR + '<%s %s />\n' % (tag, NS)


parts = [
    ('Header.cui', HDR + (
        '<CustSection %s>\n'
        '  <FileVersion MajorVersion="0" MinorVersion="6" '
        'IncrementalVersion="1" UserVersion="0" />\n'
        '  <Header>\n    <CommonConfiguration>\n      <CommonItems>\n'
        '        %s\n      </CommonItems>\n    </CommonConfiguration>\n'
        '  </Header>\n</CustSection>\n' % (NS, REV))),
    ('WorkspaceRoot.cui', HDR + '<WorkspaceRoot %s>\n'
     '  <WorkspaceConfigRoot />\n</WorkspaceRoot>\n' % NS),
    ('MenuGroup.cui', MENUGROUP),
    ('AcceleratorRoot.cui', empty('AcceleratorRoot')),
    ('OverrideRoot.cui', empty('OverrideRoot')),
    ('MouseButtonRoot.cui', empty('MouseButtonRoot')),
    ('PopMenuRoot.cui', empty('PopMenuRoot')),
    ('ToolbarRoot.cui', TOOLBAR),
    ('DoubleClickRoot.cui', empty('DoubleClickRoot')),
    ('QuickPropertiesRoot.cui', empty('QuickPropertiesRoot')),
    ('RolloverTooltipRoot.cui', empty('RolloverTooltipRoot')),
    ('RibbonRoot.cui', RIBBON),
    ('QuickAccessToolbarRoot.cui', empty('QuickAccessToolbarRoot')),
    ('ToolPanelRoot.cui', empty('ToolPanelRoot')),
    ('PanelSetRoot.cui', empty('PanelSetRoot')),
    ('ScreenMenuRoot.cui', empty('ScreenMenuRoot')),
    ('ImageMenuRoot.cui', empty('ImageMenuRoot')),
    ('TabletMenuRoot.cui', empty('TabletMenuRoot')),
    ('DigitizerButtonRoot.cui', empty('DigitizerButtonRoot')),
    ('LSPFiles.cui', empty('LSPFiles')),
]

icons = sorted(x for x in os.listdir(ICONS) if x.endswith('.bmp'))

rels = ['<?xml version="1.0" encoding="utf-8"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/'
        'package/2006/relationships">']
rid = 0
for name, _ in parts:
    rid += 1
    rels.append('<Relationship Type="CUI" Target="/%s" Id="Rgr%08x" />'
                % (name, rid))
for name in icons:
    rid += 1
    rels.append('<Relationship Type="Image" Target="/%s" Id="Rgr%08x" />'
                % (name, rid))
rels.append('</Relationships>')

CT = ('<?xml version="1.0" encoding="utf-8"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/'
      'content-types">'
      '<Default Extension="cui" ContentType="text/xml" />'
      '<Default Extension="bmp" ContentType="image/bmp" />'
      '<Default Extension="xml" ContentType="text/xml" />'
      '<Default Extension="rels" ContentType="application/'
      'vnd.openxmlformats-package.relationships+xml" />'
      '</Types>')

# --- Menu_Package_Info.xml -------------------------------------------
# Манифест частей пакета. Без него AutoCAD не подхватывает содержимое:
# иконки не попадают в .mnr, а лента остаётся пустой. Запись
# /VirtualMNRRoot - виртуальная, отдельного файла в архиве ей не нужно.
import datetime

stamp = datetime.datetime.now().astimezone().isoformat()

mpi = ['<?xml version="1.0" encoding="utf-8"?>\n<MenuPackageParts>\n']
for name, _ in parts:
    mpi.append('  <PartData PartData_Name="/%s" PartData_Modified="%s" />\n'
               % (name, stamp))
mpi.append('  <PartData PartData_Name="/VirtualMNRRoot" '
           'PartData_Modified="%s" />\n' % stamp)
mpi.append('  <PartData PartData_Name="/Menu_Package_Info.xml" '
           'PartData_Modified="%s" />\n' % stamp)
for name in icons:
    mpi.append('  <PartData PartData_Name="/%s" PartData_Modified="%s" />\n'
               % (name, stamp))
mpi.append('</MenuPackageParts>\n')
MPI = ''.join(mpi)

with zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED) as z:
    z.writestr('[Content_Types].xml', CT.encode('utf-8'))
    z.writestr('_rels/.rels', ''.join(rels).encode('utf-8'))
    for name, body in parts:
        z.writestr(name, body.encode('utf-8'))
    z.writestr('Menu_Package_Info.xml', MPI.encode('utf-8'))
    for name in icons:
        z.write(os.path.join(ICONS, name), name)

print('собран:', OUT, os.path.getsize(OUT), 'байт')
print('макросов:', len(macros), '| в списке форматов:', len(FORMAT_MACROS) + 1,
      '| иконок:', len(icons))
