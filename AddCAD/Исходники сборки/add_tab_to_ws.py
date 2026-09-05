# -*- coding: utf-8 -*-
"""Регистрация вкладки ГеоРамки в рабочем пространстве AutoCAD.

WorkspaceBehavior="AddTabOnly" добавляет вкладку в рабочее пространство только
при первой загрузке группы адаптации. Группа GEORAMKI уже загружалась раньше,
поэтому запись в Profile.aws не появилась и вкладка не показывается.
Дописываем её сами. AutoCAD при этом обязан быть закрыт - при выходе
он перезаписывает Profile.aws целиком.
"""
import io
import os
import shutil
import sys

AWS = sys.argv[1]

GROUP = 'GEORAMKI'
TAB = 'RBNU_GR_TAB'
PANEL = 'RBNU_GR_PANEL'

d = io.open(AWS, encoding='utf-8').read()

if 'MenuGroup="%s"' % GROUP in d:
    print('вкладка уже зарегистрирована, ничего не меняю')
    sys.exit(0)

anchor = '</WSRibbonRoot>'
k = d.find(anchor)
if k < 0:
    print('ОШИБКА: не найден WSRibbonRoot')
    sys.exit(1)

# отступы берём такие же, как у соседних записей
block = (
    '\t\t\t\t<WSRibbonTabSourceReference MenuGroup="%s" TabId="%s" '
    'Show="true" IsActive="false" UID="WSRU_GR_00001">\n'
    '\t\t\t\t\t<ModifiedRev MajorVersion="25" MinorVersion="0" UserVersion="1"/>\n'
    '\t\t\t\t\t<WSRibbonPanelSourceReference PanelId="%s" Orientation="Docked" '
    'Show="true" xval="0" yval="0" FloatingGroup="0" FloatingOrder="0" '
    'FloatingOrientation="Vertical" PanelResizeOrder="100"/>\n'
    '\t\t\t\t</WSRibbonTabSourceReference>\n'
    % (GROUP, TAB, PANEL))

bak = AWS + '.georamki.bak'
if not os.path.exists(bak):
    shutil.copy2(AWS, bak)
    print('бэкап:', os.path.basename(bak))

# вставляем перед закрывающим тегом, сохраняя его собственный отступ
tail_start = d.rfind('\n', 0, k)
new = d[:tail_start + 1] + block + d[tail_start + 1:]
io.open(AWS, 'w', encoding='utf-8', newline='').write(new)

print('вкладка %s добавлена в рабочее пространство' % GROUP)
print('было %d байт, стало %d' % (len(d), len(new)))
