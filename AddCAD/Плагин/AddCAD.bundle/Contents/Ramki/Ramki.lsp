;;; ======================================================================
;;;  AddCAD - Рамки
;;;  Форматы А0-А4, горизонтальные и вертикальные, плюс штамп.
;;;
;;;  ЭТО ИСХОДНИК В UTF-8. В плагин файл кладётся перекодированным в CP1251:
;;;      iconv -f UTF-8 -t CP1251 Ramki_src_utf8.lsp > Ramki.lsp
;;;
;;;  Команды. Канонические идут с префиксом "А" - он отделяет команды
;;;  AddCAD от чужих надстроек. Короткие оставлены алиасами для удобства.
;;;
;;;    АРАМКА    (ARAMKA)  - вставка рамки с выбором формата
;;;       алиас: РАМКА, RAMKA
;;;    АШТАМП    (ASHTAMP) - вставка штампа на слой "Штамп"
;;;       алиас: ШТАМП, SHTAMP
;;;    АМАСШТАБ  (ASCALE)  - динамический масштаб или фиксированное значение
;;;       алиас: РАМКАМАСШТАБ, RAMKASCALE
;;;
;;;    Р0Г..Р4В / R0G..R4V - быстрая вставка конкретного формата.
;;;       Эти намеренно без префикса: они короткие по назначению,
;;;       а сочетание "буква-цифра-буква" и так почти не конфликтует.
;;;
;;;  Рамка висит на курсоре, пока не укажешь точку. Дальше по умолчанию
;;;  включается масштабирование от этой точки - тянешь мышью и видишь
;;;  результат, либо вводишь число с клавиатуры.
;;; ======================================================================

(vl-load-com)

;;; --- где лежат блоки --------------------------------------------------
;;; Ищем по списку кандидатов: пользовательская установка, затем общая.

(defun gr:dir ( / cands)
  (if (and *gr:dir* (findfile (strcat *gr:dir* "A3_gor.dwg")))
    *gr:dir*
    (progn
      (setq cands
        (list
          (strcat (getenv "APPDATA")
                  "\\Autodesk\\ApplicationPlugins\\AddCAD.bundle\\Contents\\Ramki\\Blocks\\")
          (strcat (getenv "ProgramData")
                  "\\Autodesk\\ApplicationPlugins\\AddCAD.bundle\\Contents\\Ramki\\Blocks\\")))
      (setq *gr:dir* nil)
      (foreach c cands
        (if (and (null *gr:dir*) (findfile (strcat c "A3_gor.dwg")))
          (setq *gr:dir* c)))
      (if (null *gr:dir*)
        (princ "\nAddCAD/Рамки: не найдена папка с блоками."))
      *gr:dir*)))

;;; --- сохранение / восстановление окружения ----------------------------
;;; OSMODE намеренно не трогаем: привязки нужны при указании точки вставки.

(defun gr:save ()
  (setq *gr:env* (list (getvar "CMDECHO")
                       (getvar "ATTREQ")
                       (getvar "ATTDIA")
                       (getvar "CLAYER")))
  (setvar "CMDECHO" 0)
  (setvar "ATTREQ" 0)
  (setvar "ATTDIA" 0))

(defun gr:restore ()
  (if *gr:env*
    (progn
      (setvar "CMDECHO" (nth 0 *gr:env*))
      (setvar "ATTREQ"  (nth 1 *gr:env*))
      (setvar "ATTDIA"  (nth 2 *gr:env*))
      (if (tblsearch "LAYER" (nth 3 *gr:env*))
        (setvar "CLAYER" (nth 3 *gr:env*)))
      (setq *gr:env* nil))))

;;; Если прервали Esc на этапе масштабирования, вставленный блок остаётся
;;; висеть в чертеже. Считаем отмену отменой и убираем его.
(defun gr:err (msg)
  (if (and msg (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*ОТМЕНА*")))
    (princ (strcat "\nОшибка: " msg)))
  (if (and *gr:pending* (entget *gr:pending*))
    (entdel *gr:pending*))
  (setq *gr:pending* nil)
  (gr:restore)
  (setq *error* *gr:olderr* *gr:olderr* nil)
  (princ))

;;; --- надписи "Лист / Листов / 1 / 1" ----------------------------------
;;; В штампе эти ячейки нарисованы, но пустые - в исходных DWG текста нет.
;;; Дочерчиваем его сами после взрыва рамки, сами файлы не трогаем.
;;;
;;; Ячейки находим геометрически: в правой части штампа есть ровно одна
;;; пара вертикальных отрезков длиной 15 на расстоянии 15 друг от друга.
;;; Поэтому код работает для всех форматов, где штамп смещён по-разному,
;;; и не зависит ни от точки вставки, ни от масштаба.

(defun gr:newlines (prev sc / e d s p lines tol len)
  (setq tol (* 0.02 sc)
        len (* 15.0 sc)
        lines '()
        e prev)
  (while (setq e (if e (entnext e) (entnext)))
    (setq d (entget e))
    (if (= (cdr (assoc 0 d)) "LINE")
      (progn
        (setq s (cdr (assoc 10 d))
              p (cdr (assoc 11 d)))
        (if (and (< (abs (- (car s) (car p))) tol)
                 (< (abs (- (abs (- (cadr s) (cadr p))) len)) tol))
          (setq lines
                (cons (list (car s)
                            (min (cadr s) (cadr p))
                            (max (cadr s) (cadr p)))
                      lines))))))
  lines)

(defun gr:grid (lines sc / res tol len)
  (setq tol (* 0.02 sc) len (* 15.0 sc) res nil)
  (foreach a lines
    (foreach b lines
      (if (and (null res)
               (< (abs (- (- (car b) (car a)) len)) tol)
               (< (abs (- (cadr a) (cadr b))) tol))
        (setq res a))))
  res)

(defun gr:label (x y sc txt)
  (entmake
    (list '(0 . "MTEXT")
          '(100 . "AcDbEntity")
          (cons 8 "рамка")
          '(100 . "AcDbMText")
          (cons 10 (list x y 0.0))
          (cons 40 (* 3.0 sc))
          (cons 41 0.0)
          (cons 71 5)                    ; привязка: центр по обеим осям
          (cons 7 "ГОСТ")
          (cons 1 (strcat "{\\T0.9;" txt "}")))))

(defun gr:addlabels (prev sc / g ymid ytop ybot xl xr)
  (if (setq g (gr:grid (gr:newlines prev sc) sc))
    (progn
      (setq ymid (+ (cadr g) (* 10.0 sc))
            ytop (/ (+ (caddr g) ymid) 2.0)
            ybot (/ (+ ymid (cadr g)) 2.0)
            xl   (- (car g) (* 7.5 sc))
            xr   (+ (car g) (* 7.5 sc)))
      (gr:label xl ytop sc "Лист")
      (gr:label xr ytop sc "Листов")
      (gr:label xl ybot sc "1")
      (gr:label xr ybot sc "1")
      T)))

;;; --- вставка ----------------------------------------------------------
;;; PAUSE отдаёт указание точки самой команде -ВСТАВИТЬ, поэтому блок
;;; висит на курсоре и сразу видно, как он встанет.
;;;
;;; *gr:scale* = nil    - динамический режим: после вставки сразу МАСШТАБ
;;; *gr:scale* = число  - фиксированный: масштаб задаётся до точки вставки,
;;;                       и на курсоре блок уже нужного размера.
;;;
;;; command вызывается напрямую: обернуть его в vl-catch-all-apply нельзя,
;;; AutoLISP отвечает "неверная порядковая функция: COMMAND".

(defun gr:insert (name / dir file src prev ent pt sc)
  (setq dir (gr:dir))
  (if (null dir)
    nil
    (progn
      (setq file (strcat dir name ".dwg"))
      ;; путь берём в кавычки: иначе пробелы в нём будут восприняты как Enter
      (setq src (if (tblsearch "BLOCK" name) name (strcat "\"" file "\"")))
      (setq prev (entlast))

      (if *gr:scale*
        (command "_.-INSERT" src "_S" *gr:scale* PAUSE 0)
        (command "_.-INSERT" src PAUSE 1 1 0))

      (setq ent (entlast))
      (if (and ent (not (eq ent prev)))
        (progn
          (setq sc (if *gr:scale* *gr:scale* 1.0))
          (if (null *gr:scale*)
            (progn
              (setq pt (cdr (assoc 10 (entget ent))))
              (princ "\nМасштаб: тяните мышью или введите число.")
              (setq *gr:pending* ent)
              (command "_.SCALE" ent "" pt PAUSE)
              (setq *gr:pending* nil)
              (if (entget ent)
                (progn
                  (setq sc (cdr (assoc 41 (entget ent))))
                  (if (or (null sc) (<= sc 0.0)) (setq sc 1.0))
                  (princ (strcat "\nМасштаб рамки: " (rtos sc 2 4)))))))
          (if (entget ent)
            (progn
              ;; prev - последний объект до вставки: всё, что появится
              ;; после взрыва, идёт по цепочке за ним
              (command "_.EXPLODE" ent)
              (gr:addlabels prev sc)))))

      (command "_.-PURGE" "_Blocks" name "_No")
      T)))

;;; --- общее тело команды -----------------------------------------------

(defun gr:frame (name)
  (setq *gr:olderr* *error*  *error* gr:err)
  (gr:save)
  (gr:insert name)
  (gr:restore)
  (setq *error* *gr:olderr* *gr:olderr* nil)
  (princ))

;;; быстрая вставка отличается только тем, что формат уже известен
(defun gr:quick (name) (gr:frame name))

;;; ======================================================================
;;;  Команды
;;; ======================================================================

;;; АРАМКА - выбор формата и ориентации диалогом в командной строке

(defun c:АРАМКА ( / fmt ori)
  (if (null *gr:fmt*) (setq *gr:fmt* "3"))
  (if (null *gr:ori*) (setq *gr:ori* "gor"))
  (initget "0 1 2 3 4")
  (setq fmt (getkword (strcat "\nФормат А [0/1/2/3/4] <" *gr:fmt* ">: ")))
  (if fmt (setq *gr:fmt* fmt))
  (initget "Горизонтально Вертикально")
  (setq ori (getkword
              (strcat "\nОриентация [Горизонтально/Вертикально] <"
                      (if (= *gr:ori* "gor") "Г" "В") ">: ")))
  (if ori (setq *gr:ori* (if (= ori "Горизонтально") "gor" "vert")))
  (gr:frame (strcat "A" *gr:fmt* "_" *gr:ori*)))

(defun c:ARAMKA () (c:АРАМКА))
(defun c:РАМКА  () (c:АРАМКА))
(defun c:RAMKA  () (c:АРАМКА))

;;; АМАСШТАБ - переключение между динамикой и фиксированным масштабом

(defun c:АМАСШТАБ ( / s)
  (initget "Динамически")
  (setq s (getreal
            (strcat "\nМасштаб рамок [Динамически] <"
                    (if *gr:scale* (rtos *gr:scale* 2 4) "динамически")
                    ">: ")))
  (cond
    ((= s "Динамически") (setq *gr:scale* nil))
    ((and s (numberp s) (> s 0.0)) (setq *gr:scale* s)))
  (princ (strcat "\nРежим: "
                 (if *gr:scale*
                   (strcat "фиксированный масштаб " (rtos *gr:scale* 2 4))
                   "динамический, масштаб задаётся мышью при вставке")))
  (princ))

(defun c:ASCALE       () (c:АМАСШТАБ))
(defun c:РАМКАМАСШТАБ () (c:АМАСШТАБ))
(defun c:RAMKASCALE   () (c:АМАСШТАБ))

;;; АШТАМП - вставка штампа на отдельный слой

(defun c:АШТАМП ()
  (setq *gr:olderr* *error*  *error* gr:err)
  (gr:save)
  (if (null (tblsearch "LAYER" "Штамп"))
    (command "_.-LAYER" "_Make" "Штамп" "")
    (setvar "CLAYER" "Штамп"))
  (gr:insert "shtamp")
  (gr:restore)
  (setq *error* *gr:olderr* *gr:olderr* nil)
  (princ))

(defun c:ASHTAMP () (c:АШТАМП))
(defun c:ШТАМП   () (c:АШТАМП))
(defun c:SHTAMP  () (c:АШТАМП))

;;; --- быстрые команды Р0Г..Р4В и R0G..R4V ------------------------------
;;; Определяются циклом, чтобы не плодить два десятка одинаковых defun.

(foreach f '("0" "1" "2" "3" "4")
  (foreach o '(("gor" "Г" "G") ("vert" "В" "V"))
    (eval (list 'defun (read (strcat "c:Р" f (cadr o)))  '()
                (list 'gr:quick (strcat "A" f "_" (car o)))))
    (eval (list 'defun (read (strcat "c:R" f (caddr o))) '()
                (list 'gr:quick (strcat "A" f "_" (car o)))))))

(princ "\nAddCAD/Рамки. Команды: АРАМКА, АШТАМП, быстрые Р3Г / Р4В и т.п.")
(princ)
