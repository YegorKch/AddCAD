import io, sys

path = sys.argv[1]
src = io.open(path, encoding='utf-8').read()

BS = chr(92)      # обратный слэш
Q = '"'

depth = 0
instr = False
esc = False
line = 1
bad = []
i = 0
while i < len(src):
    c = src[i]
    if c == '\n':
        line += 1
    if instr:
        if esc:
            esc = False
        elif c == BS:
            esc = True
        elif c == Q:
            instr = False
    else:
        if c == ';':
            while i < len(src) and src[i] != '\n':
                i += 1
            line += 1
        elif c == Q:
            instr = True
        elif c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth < 0:
                bad.append(('лишняя закрывающая', line))
                depth = 0
    i += 1

print('итоговая глубина скобок:', depth, '(должно быть 0)')
print('осталась незакрытая строка:', instr, '(должно быть False)')
print('ошибки:', bad if bad else 'нет')
