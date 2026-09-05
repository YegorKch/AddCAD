;;; ======================================================================
;;;  ГеоРамки - обезличивание штампов
;;;
;;;  Команда: ГРТЕКСТЫ
;;;
;;;  Все содержательные надписи заменяются на "ТЕКСТ". Остаются только
;;;  оформительские обозначения по ГОСТ 2.104: Должность, Ф.И.О.,
;;;  Подпись, Дата, Формат, Лист/Листов.
;;;
;;;  Смысл: формы рамок и штампов - государственный стандарт, а вот
;;;  конкретные формулировки были авторскими. После обезличивания
;;;  вопрос о заимствовании снимается совсем: остаётся чистый бланк,
;;;  который заполняется под задачу.
;;;
;;;  Форматирование сохраняется: если надпись была центрированной
;;;  (код \pxqc), центрирование остаётся.
;;;
;;;  Работает через ObjectDBX: чертежи открываются в памяти, без окон.
;;;  Запускать ИЗНУТРИ AutoCAD - снаружи, через внешний COM, SaveAs
;;;  подвешивает приложение.
;;;
;;;  Повторный запуск безопасен: заменять будет уже нечего.
;;; ======================================================================

(vl-load-com)

;;; Надписи, которые остаются как есть. Это стандартные обозначения
;;; граф основной надписи, они и должны быть дословными.
(setq *gt:keep*
  '("Должность" "Ф.И.О." "Дата" "Подпись" "Формат" "Лист"))

(defun gt:keep-p (s / hit)
  (setq hit nil)
  (foreach w *gt:keep*
    (if (and (not hit) (vl-string-search w s)) (setq hit T)))
  hit)

;;; Пустой бланк вместо содержательной надписи, с сохранением
;;; горизонтального центрирования, если оно было.
(defun gt:blank (s)
  (strcat (if (vl-string-search "\\pxqc;" s) "\\pxqc;" "")
          "{\\T0.9;ТЕКСТ}"))

(defun gt:dir ( / cands d)
  (setq cands
    (list
      (strcat (getenv "APPDATA")
              "\\Autodesk\\ApplicationPlugins\\GeoRamki.bundle\\Contents\\Blocks\\")
      (strcat (getenv "ProgramData")
              "\\Autodesk\\ApplicationPlugins\\GeoRamki.bundle\\Contents\\Blocks\\")))
  (setq d nil)
  (foreach c cands
    (if (and (null d) (findfile (strcat c "A3_gor.dwg"))) (setq d c)))
  d)

;;; ======================================================================

(defun c:ГРТЕКСТЫ ( / dir names dbx ms file was now changed total files)
  (setq dir (gt:dir))
  (if (null dir)
    (progn (princ "\nНе найдена папка Blocks плагина ГеоРамки.") (princ))
    (progn
      (setq names '("A0_gor" "A0_vert" "A1_gor" "A1_vert"
                    "A2_gor" "A2_vert" "A3_gor" "A3_vert"
                    "A4_gor" "A4_vert" "shtamp")
            total 0
            files 0
            dbx (vla-GetInterfaceObject
                  (vlax-get-acad-object) "ObjectDBX.AxDbDocument.25"))
      (foreach n names
        (setq file (strcat dir n ".dwg"))
        (if (findfile file)
          (progn
            (vla-Open dbx file)
            (setq ms (vla-get-ModelSpace dbx)
                  changed 0)
            (vlax-for o ms
              (if (= (vla-get-ObjectName o) "AcDbMText")
                (progn
                  (setq was (vla-get-TextString o))
                  (if (not (gt:keep-p was))
                    (progn
                      (setq now (gt:blank was))
                      (if (/= was now)
                        (progn
                          (vla-put-TextString o now)
                          (setq changed (1+ changed)))))))))
            (if (> changed 0)
              (progn
                (vla-SaveAs dbx file)
                (setq files (1+ files)
                      total (+ total changed))
                (princ (strcat "\n" n " - обезличено надписей: "
                               (itoa changed))))
              (princ (strcat "\n" n " - менять нечего"))))
          (princ (strcat "\n" n " - файла нет"))))
      (vlax-release-object dbx)
      (princ (strcat "\n\nГотово. Файлов изменено: " (itoa files)
                     ", надписей обезличено: " (itoa total)))
      (princ "\nВставьте рамку заново, чтобы увидеть результат.")
      (princ))))

(defun c:GRTEXTS () (c:ГРТЕКСТЫ))

(princ "\nЗагружено. Команда ГРТЕКСТЫ - обезличить надписи в штампах.")
(princ)
